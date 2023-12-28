#
# Proof of Concept to generate log information in ApplicationInsights
# Azure Functions have its own logging as well. That's disabled in the host.json:
#     "logLevel": {
#      "default": "None",    <-- This line
#
import json
import random
import time
import logging
import azure.functions as func

# Open Telemetry
from azure.monitor.opentelemetry import configure_azure_monitor
from opentelemetry import trace

# Workaround (part 1/3) specifically for Azure Functions, according to: https://learn.microsoft.com/en-us/azure/azure-monitor/app/opentelemetry-python-opencensus-migrate
from opentelemetry.context import attach, detach
from opentelemetry.trace.propagation.tracecontext import TraceContextTextMapPropagator

from run import Run
from metrics import metric_batch, metric_run, metric_retried_run, metric_retried_run, metric_completed_run, metric_tasks_count, metric_failed_run

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
@app.function_name(name="pma5poc-loggen-app")
@app.route(route="FakeLogGenerator", auth_level=func.AuthLevel.ANONYMOUS)
def FakeLogGenerator(req: func.HttpRequest, context) -> func.HttpResponse:
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

    # Extract the machinenr from the POST request
    # Read json to get the parameter values
    with tracer.start_as_current_span("Parse Tasker params") as span:
        if req.method != "POST": return func.HttpResponse("Must send a POST request.", status_code=400)
        try:
            run = Run.create(req.get_json())
        except ValueError as error:
            return func.HttpResponse(error, status_code=400)


    # Start the simulation of a Tasker run
    with tracer.start_as_current_span("Execute tasker", record_exception=False, attributes=run.metadata):
        try:
            # Track the start of a new run (sample for using an observable up/down counter)
            parallel_runs_tracker.register_start_run(run)

            # Log start of the batch (which can consist of this one and possible retry runs)
            if (run.iteration==1):
                logging.info(f'Tasker started batch', extra=run.metadata)
                metric_batch.add(1,attributes=run.metadata)

            # Consider: shouldn't we use the "Tasker started retry" for retries? More expressive but counting runs will have to count both. 
            logging.info(f'Tasker started run', extra=run.metadata)

            # Show the information also in the log text, as well as in the dimensions
            if (run.iteration>1):
                metric_retried_run.add(1,attributes=run.metadata)
            else:
                metric_run.add(1,attributes=run.metadata)

            # Simulate processing (to make the timestamps more realistic) and how many tasks were created
            time.sleep(run.duration)
            tasks_created_count = random.randrange(30,200)

            # If an error was specified: abort the run with that error
            if (run.error is not None):
                raise Exception(run.error)

            # When successful, update metrics and logs
            metric_tasks_count.add(tasks_created_count,attributes=run.metadata)
            metric_completed_run.add(1,attributes=run.metadata)

            # Add the tasks_created and duration in the meta data so we can report on it
            run.metadata["tasks_created"] = tasks_created_count
            run.metadata["duration"] = run.duration
            logging.info(f'Tasker completed run',extra=run.metadata)

            # Done with all of it, return 200 (OK)
            return func.HttpResponse(json.dumps(run.metadata), mimetype="application/json", status_code=200)
        
        except Exception as error:
            # Log the exception (which includes the traceback)
            # On the span, set record_exception=False because we handle it here and include more info
            logging.exception(f'Tasker error handled!',exc_info=error, extra=run.metadata)

            # And log a more simple error message
            logging.error(f'Tasker failed run',extra=run.metadata)
            metric_failed_run.add(1,attributes=run.metadata)

            # Indicate it failed, return 500 (Server error)
            return func.HttpResponse(json.dumps(run.metadata), mimetype="application/json", status_code=500)

        finally:
            # Update the counter for the parallel runs
            parallel_runs_tracker.register_end_run(run)
