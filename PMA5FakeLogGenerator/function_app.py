# Safeguard against errors while loading the imports
# This will ensure we get at least some troubleshooting info about it.
import json
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
from parse_http_request import extract_run_from_request
from metrics import metric_batch, metric_run, metric_retried_run, metric_retried_run, metric_manual_run, metric_completed_run, metric_failed_run

# Enable telemetry for this Azure Function
# TODO Pass a storage_directory for storing logs when offline
# TODO Pass credential=ManagedIdentityCredential() to authenticate to ApplicationInsights
configure_azure_monitor()
tracer = trace.get_tracer(__name__)

# Create a object to keep track of the parallel runs so an observable UpDown metric can report on it
from metrics import ParallelRunsTracker, create_parallel_runs_observable_updown_counter 
parallelRunsTracker=ParallelRunsTracker()
metric_updown_parallel_runs=create_parallel_runs_observable_updown_counter(parallelRunsTracker)

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
    with tracer.start_as_current_span("Extract parameters from request") as span:
        if req.method != "POST": return func.HttpResponse("Must send a POST request.", status_code=400)
        run = extract_run_from_request(req)
        span.set_attribute("machinenr",run.machinenr) # Support finding the span by the machinenr
        if not run.is_valid(): return func.HttpResponse("Body must contain machinenr, runDuration, isSuccessful, isManualRun, batchId, runNr and processName.", status_code=400)


    # Start the simulation of a Tasker run
    with tracer.start_as_current_span("Tasker execution", record_exception=False, attributes=run.logMetadata):
        try:
            # Track the start of a new run (sample for using an observable up/down counter)
            parallelRunsTracker.register_start_run(run)

            # Log start of the batch (which can consist of this one and possible retry runs)
            if (run.is_new_batch):
                logging.info(f'{run.processName} started batch', extra=run.logMetadata)
                metric_batch.add(1,{"machinenr":run.machinenr,"batchId":run.batchId})

            # Show the information also in the log text, as well as in the dimensions
            if (run.is_retry):
                logging.info(f'{run.processName} started retry ({run.runLabel})', extra=run.logMetadata)
                metric_retried_run.add(1,attributes=run.logMetadata)
            else:
                logging.info(f'{run.processName} started run', extra=run.logMetadata)
                metric_run.add(1,attributes=run.logMetadata)

            if (run.is_manual_run):
                metric_manual_run.add(1,{"machinenr":run.machinenr,"batchId":run.batchId})

            # Simulate processing time
            time.sleep(run.runDuration)

            # Simulate that something aborts the process
            if (not run.is_successful):
                raise Exception(f'Some fake exception for {run.processName}')

            # Run completed successfully
            metric_completed_run.add(1,attributes=run.logMetadata)
            logging.info(f'{run.processName} completed run ({run.runLabel})',extra=run.logMetadata)

            # Done with all of it, return 200 (OK)
            return func.HttpResponse(json.dumps(run.logMetadata), mimetype="application/json", status_code=200)
        
        except Exception as error:
            # Log the exception (which includes the traceback)
            # On the span, set record_exception=False because we handle it here and include more info
            logging.exception(f'{run.processName} error handled!',exc_info=error, extra=run.logMetadata)

            # And log a more simple error message
            logging.error(f'{run.processName} failed run ({run.runLabel})',extra=run.logMetadata)
            metric_failed_run.add(1,attributes=run.logMetadata)

            # Indicate it failed, return 500 (Server error)
            return func.HttpResponse(json.dumps(run.logMetadata), mimetype="application/json", status_code=500)

        finally:
            # Update the counter for the parallel runs
            parallelRunsTracker.register_end_run(run)
