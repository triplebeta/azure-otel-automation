#
# Proof of Concept to generate log information in ApplicationInsights
# Azure Functions have its own logging as well. That's disabled in the host.json:
#     "logLevel": {
#      "default": "None",    <-- This line
#

import uuid
import random
import time
import json
import logging
import azure.functions as func

# Open Telemetry
from azure.monitor.opentelemetry import configure_azure_monitor
from opentelemetry import trace

# Workaround (part 1/3) specifically for Azure Functions, according to: https://learn.microsoft.com/en-us/azure/azure-monitor/app/opentelemetry-python-opencensus-migrate
from opentelemetry.context import attach, detach
from opentelemetry.trace.propagation.tracecontext import TraceContextTextMapPropagator

from task_simulation_request import TasksSimulationRequest
from metrics import metric_batch, metric_run, metric_run_retried, metric_run_retried, metric_run_completed, metric_tasks_count, metric_run_failed

# Avoid duplicate logging
root_logger = logging.getLogger()
for handler in root_logger.handlers[:]:
    root_logger.removeHandler(handler)

# Enable telemetry for this Azure Function
# TODO Pass a storage_directory for storing logs when offline
# TODO Pass credential=ManagedIdentityCredential() to authenticate to ApplicationInsights
configure_azure_monitor()
tracer = trace.get_tracer(__name__)

# Create a object to keep track of the parallel runs so an observable UpDown metric can report on it
from metrics import ParallelRunsTracker, create_parallel_runs_observable_updown_counter 
parallel_runs_tracker=ParallelRunsTracker()
metric_updown_parallel_runs=create_parallel_runs_observable_updown_counter(parallel_runs_tracker)

app = func.FunctionApp()

# Tasks: Simulate creating tasks when events sends a trigger.
# Cardinality can be set to "many" or to "one".
# It will log more metrics when using "many" 
# 
@app.function_name(name="TaskerFake")
@app.event_hub_message_trigger(arg_name="myEvents", event_hub_name='eventsgbr', cardinality="one", connection="EVENTHUB_CONNECTION_STRING") 
def TaskerFake(myEvents: func.EventHubEvent, context):
     """
          Generates fake log and telemetry entries.
     """

     # TODO Check if this is still necessary or that it was only needed in early versions.
     # Workaround (part 2/3) to on context information.
     functions_current_context = {
          "traceparent": context.trace_context.Traceparent,
          "tracestate": context.trace_context.Tracestate
     }
     parent_context = TraceContextTextMapPropagator().extract(carrier=functions_current_context)
     token = attach(parent_context)

     try:
          # Extract the info from the Event Hub message
          # Read json to get the parameter values
          with tracer.start_as_current_span("Parse Tasker params") as span:
               try:
                    msgFromEventsGBR = myEvents.get_body().decode("utf-8")
                    jsonBody = json.loads(msgFromEventsGBR)
                    params = TasksSimulationRequest(jsonBody)
               except ValueError as error:
                    logging.error("Failed to parse message from ")
                    raise

          # Simulate a run an perhaps some retries. All of these are the same batch.
          # Generate an id for the batch (1 or more runs)
          batch_id = 'batch-' + uuid.uuid4().hex

          # Note: if tasks_iterations = 1 then this loop will run once, with counter=0
          for counter in range(params.tasks_iterations):
               run_id = 'run-'+uuid.uuid4().hex

               # Only simulate Manual runs for retries (just as an example)
               if (counter>0): manual_retry = params.tasks_is_manual
               else: manual_retry = False

               # For convenience, define a list of all the attributes to add as dimensions for a trace or metric.
               # Include is_manual_run only if it's a manual run
               metadata={"machine":params.machine_nr, "batch_id":batch_id, "run_id":run_id, "iteration":counter+1}
               if (manual_retry): metadata["manual"]=manual_retry  # Only add this if it's a manual run 

               # Start the simulation of a Tasker run
               with tracer.start_as_current_span(f"Execute tasker (iteration={counter+1})", record_exception=False, attributes=metadata):
                    try:
                         # Track the start of a new run (sample for using an observable up/down counter)
                         parallel_runs_tracker.register_start_run(params)

                         # Log start of the batch (which can consist of this one and possible retry runs)
                         if (counter==0):
                              logging.info(f'Tasker started batch', extra=metadata)
                              metric_batch.add(1,attributes=metadata)

                         # Consider: shouldn't we use the "Tasker started retry" for retries? More expressive but counting runs will have to count both. 
                         logging.info(f'Tasker started run', extra=metadata)

                         # Show the information also in the log text, as well as in the dimensions
                         if (counter>0):
                              metric_run_retried.add(1,attributes=metadata)
                         else:
                              metric_run.add(1,attributes=metadata)

                         # If an error was specified: abort the run with that error
                         if (params.tasks_error is not None):
                              if (counter+1<params.tasks_iterations or params.tasks_success==False):
                                   raise Exception(params.tasks_error)

                         # Simulate processing (to make the timestamps more realistic) and how many tasks were created
                         time.sleep(params.tasks_duration)

                         # When successful, update metrics and logs
                         tasks_created_count = random.randrange(30,200)
                         metric_tasks_count.add(tasks_created_count,attributes=metadata)
                         metric_run_completed.add(1,attributes=metadata)

                         # Add the tasks_created and duration in the meta data so we can report on it
                         metadata["tasks_created"] = tasks_created_count
                         metadata["duration"] = params.tasks_duration
                         logging.info(f'Tasker completed run',extra=metadata)
               
                    except Exception as error:
                         # Log the exception (which includes the traceback)
                         # On the span, set record_exception=False because we handle it here and include more info
                         logging.exception(f'Tasker error handled!',exc_info=error, extra=metadata)

                         # And log a more simple error message
                         logging.error(f'Tasker failed run',extra=metadata)
                         metric_run_failed.add(1,attributes=metadata)

                    finally:
                         # Update the counter for the parallel runs
                         parallel_runs_tracker.register_end_run(params)     
               # with
          # for
     finally:
          # Workaround (part 3/3)
          token = detach(token)

