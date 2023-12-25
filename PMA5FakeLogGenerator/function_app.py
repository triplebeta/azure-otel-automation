# Safeguard against errors while loading the imports
# This will ensure we get at least some troubleshooting info about it.
import json
import uuid
import time
import logging
from typing import Iterable, Union
import azure.functions as func

# Open Telemetry
from azure.monitor.opentelemetry import configure_azure_monitor
from opentelemetry import trace, metrics
from opentelemetry.metrics import CallbackOptions, Observation, ObservableUpDownCounter

# Workaround (part 1/3) specifically for Azure Functions, according to: https://learn.microsoft.com/en-us/azure/azure-monitor/app/opentelemetry-python-opencensus-migrate
from opentelemetry.context import attach, detach
from opentelemetry.trace.propagation.tracecontext import TraceContextTextMapPropagator

# Enable telemetry for this Azure Function
# TODO Pass a storage_directory for storing logs when offline
# TODO Pass credential=ManagedIdentityCredential() to authenticate to ApplicationInsights
configure_azure_monitor()

# Create a tracer
tracer = trace.get_tracer(__name__)

# Entity to capture details of a run 
class Run:
    def __init__(self, machinenr: str, batchId: Union[int , type(None)], runNr: int, isSuccessful:bool, isManualRun: bool):
        # Unique identifier for each run
        self.runId = 'run-'+uuid.uuid4().hex
        self.machinenr = machinenr
        self.runNr = runNr
        self.runLabel = str(runNr)
        self.is_retry = (self.runNr>1)
        self.is_manual_run = isManualRun
        self.is_successful = isSuccessful

        # Generate an it do use for correlating all runs.
        self.batchId=batchId
        if (self.batchId=="" or self.batchId is None):
            self.is_new_batch=True
            self.batchId = 'batch-' + uuid.uuid4().hex
        else:
            self.is_new_batch=False

        # Return the generated IDs so they can be used in subsequent Postman requests.
        # This is just useful to make the requests more realistic.
        self.logMetadata={"machinenr":self.machinenr, "batchId":self.batchId, "runId":self.runId, "runNr":self.runNr}
        if (self.is_manual_run):
            self.runLabel = "manual" 
            self.logMetadata["isManualRun"]=isManualRun  # Only add this if it's a manual run 



# Used sample from https://stackoverflow.com/questions/74804185/update-observablegauge-in-open-telemetry-python
# and https://github.com/Azure/azure-sdk-for-python/tree/main/sdk/monitor/azure-monitor-opentelemetry-exporter
# and https://github.com/microsoft/ApplicationInsights-Python/blob/main/azure-monitor-opentelemetry/samples/metrics/instruments.py
# Define the object to observe in the callback of the Gauge metric.
class ParallelRunsTracker:
    def __init__(self):
        self.activeRuns = [Run]
        
    def register_start_run(self, run: Run):
        self.activeRuns.append(run)

    def register_end_run(self, run: Run):
        self.activeRuns.remove(run)

    def get_active_run_count(self) -> int:
        return len(self.activeRuns)


# Not the best example of a gauge but it helps to show how to implement an observable metric
# TODO Instead of 1 value, return an array with the number of parallel runs per machine
def create_parallel_runs_observable_updown_counter(parallelRunsTracker: ParallelRunsTracker) -> ObservableUpDownCounter:
    """ Create an async UpDown counter """
    def observable_updown_counter_func(options: CallbackOptions) -> Iterable[Observation]:
        activeRunCount = parallelRunsTracker.get_active_run_count()
        logging.info(f'Observable UpDown Counter: currently {activeRunCount} runs going on.')
        yield Observation(activeRunCount,{})

    return meter.create_observable_up_down_counter("tasks.runs.parallel", [observable_updown_counter_func],description="Number of parallel runs going on.")

# Create a object to keep track of the parallel runs so an observable UpDown metric can report on it
parallelRunsTracker=ParallelRunsTracker()


# Create metrics. unit must be one of the values from the UCUM, see: https://ucum.org/ucum
# Types of telemetry, https://www.timescale.com/blog/a-deep-dive-into-open-telemetry-metrics/
# The "observable" metrics are asynchronous. Important difference: they should NOT report delta values but absolute values. The framework will convert then them to deltas.
# Counter: delta's, only increasing
# Gauge: data you would not want to sum but might want to avg or use max.
meter = metrics.get_meter_provider().get_meter(__name__)
successfulBatchCounter = meter.create_counter(name="tasks.batches", description="Count of batches processed for a machine.")
runCounter = meter.create_counter(name="tasks.runs", description="Count all runs for a machine, incl. retries.")
retriedRunCounter = meter.create_counter(name="tasks.runs.retried", description="Count only of retry-runs for a machine.")
failedRunCounter = meter.create_counter(name="tasks.runs.failed", description="Count failed runs for a machine.")
completedRunCounter = meter.create_counter(name="tasks.runs.completed", description="Count successfully completed runs for a machine.")
manualRunCounter = meter.create_counter(name="tasks.runs.manual", description="Count manual runs for a machine.")
upDownParallelRunsCounter=create_parallel_runs_observable_updown_counter(parallelRunsTracker)


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
    with tracer.start_as_current_span("extract parameters from request") as span:
        logging.info(f"Extracting parameters from request...")
        if req.method != "POST": return func.HttpResponse("Must send a POST request.", status_code=400)
        try:
            req_body = req.get_json()
        except ValueError:
            pass
        else:
            processName = req_body.get('processName')           # Name of the process for which we will write log lines
            machinenr = req_body.get('machinenr')               # For which machine to run
            runDuration = int(req_body.get('runDuration'))      # Time to wait (seconds)
            isSuccessful = bool(req_body.get('isSuccessful'))   # Should the job succeed or fail
            isManualRun = bool(req_body.get('isManualRun'))     # true for manual runs 
            batchId = req_body.get('batchId')                   # Optional, only for retries: Id of the batch 
            
            if (req_body.get('runNr') is not None):
                runNr = int(req_body.get('runNr'))              # 1 for first run, 2 for first retry etc...
            else: runNr=1

        if not machinenr or not processName or not runDuration:
            return func.HttpResponse("Body must contain machinenr, runDuration, isSuccessful, isManualRun, batchId, runNr and processName.", status_code=400)

    # Create a new run
    activeRun = Run(machinenr, batchId, runNr, isSuccessful, isManualRun)

    with tracer.start_as_current_span("Tasker execution") as span:
        # You can also set an attribute for a span after its creation
        span.set_attribute("machinenr",activeRun.machinenr) # Support finding the span by the machinenr

        if (activeRun.is_manual_run):
            manualRunCounter.add(1,{"machinenr":activeRun.machinenr,"batchId":activeRun.batchId})

        # For now: simply use the same structure to return in the HTTP Response
        httpResponse=activeRun.logMetadata 

        # Immediately pass additional info like machinenr to the span
        with tracer.start_as_current_span("Fake process logic", record_exception=False, attributes=activeRun.logMetadata):
            try:
                # Track the start of a new run
                parallelRunsTracker.register_start_run(activeRun)

                # Log start of the batch (which can consist of this one and possible retry runs)
                if (activeRun.is_new_batch):
                    logging.info(f'{processName} started batch', extra=activeRun.logMetadata)
                    successfulBatchCounter.add(1,{"machinenr":machinenr,"batchId":activeRun.batchId})

                # Show the information also in the log text, as well as in the dimensions
                if (activeRun.is_retry):
                    logging.info(f'{processName} started retry ({activeRun.runLabel})', extra=activeRun.logMetadata)
                    retriedRunCounter.add(1,attributes=activeRun.logMetadata)
                else:
                    logging.info(f'{processName} started run ({activeRun.runLabel})', extra=activeRun.logMetadata)
                    runCounter.add(1,attributes=activeRun.logMetadata)

                # Simulate processing time
                time.sleep(runDuration)

                # Also report the duration
                if (activeRun.is_successful):
                    completedRunCounter.add(1,attributes=activeRun.logMetadata)
                    logging.info(f'{processName} completed run ({activeRun.runLabel})',extra=activeRun.logMetadata)
                else:
                    # Simulate that something aborts the process
                    raise Exception(f'Some fake exception for {processName}')

                # Done with all of it, return 200 (OK)
                return func.HttpResponse(json.dumps(httpResponse), mimetype="application/json", status_code=200)
            
            except Exception as error:
                # Log the exception (which includes the traceback)
                # On the span, set record_exception=False because we handle it here and include more info
                logging.exception(f'{processName} error handled!',exc_info=error, extra=activeRun.logMetadata)

                # And log a more simple error message
                logging.error(f'{processName} failed run ({activeRun.runLabel})',extra=activeRun.logMetadata)
                failedRunCounter.add(1,attributes=activeRun.logMetadata)

                # Indicate it failed, return 500 (Server error)
                return func.HttpResponse(json.dumps(httpResponse), mimetype="application/json", status_code=500)
            finally:
                # Register the end of the run
                parallelRunsTracker.register_end_run(activeRun)
