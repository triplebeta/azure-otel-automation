import json
import uuid
import time
import os
import datetime
import logging
import random
import azure.functions as func

# Open Telemetry
from azure.monitor.opentelemetry import configure_azure_monitor
from opentelemetry import trace, metrics
# from  applicationinsights  import  TelemetryClient

# Workaround (part 1/3) specifically for Azure Functions, according to: https://learn.microsoft.com/en-us/azure/azure-monitor/app/opentelemetry-python-opencensus-migrate
from opentelemetry.context import attach, detach
from opentelemetry.trace.propagation.tracecontext import TraceContextTextMapPropagator

configure_azure_monitor()
tracer = trace.get_tracer(__name__)
app = func.FunctionApp()

@app.route(route="FakeLogGenerator", auth_level=func.AuthLevel.ANONYMOUS)
async def FakeLogGenerator(req: func.HttpRequest, context) -> func.HttpResponse:
    """ Generates fake log entries.
        Goal is to build metrics on top of those lines.
    """

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
            jobDuration = int(req_body.get('jobDuration'))      # Time to wait (seconds)
            isSuccessful = bool(req_body.get('isSuccessful'))   # Should the job succeed or fail
            isManualRun = bool(req_body.get('isManualRun'))     # true for manual runs 
            batchId = req_body.get('batchId')                   # Optional, only for retries: Id of the batch 
            
            if (req_body.get('runNr') is not None):
                runNr = int(req_body.get('runNr'))            # 1 for first run, 2 for first retry etc...
            else: runNr=1

        if not machinenr or not processName or not jobDuration:
            return func.HttpResponse("Body must contain machinenr, jobDuration, isSuccessful, isManualRun, batchId, runNr and processName.", status_code=400)

    # machinenr value wasn't known yet at the start of the span, so set it now
    span.set_attribute("machinenr",machinenr) # Support finding the span by the machinenr

    # Generate an it do use for correlation in all steps.
    if (batchId=="" or batchId is None): batchId = 'batch-' + uuid.uuid4().hex
    runId = 'run-'+uuid.uuid4().hex

    # Return the generated IDs so they can be used in subsequent Postman requests.
    # This is just useful to make the requests more realistic.
    logMetadata={"machinenr":machinenr, "batchId":batchId, "runId":runId, "runNr":runNr}
    if (isManualRun): logMetadata["isManualRun"]=isManualRun  # Only add this if it's a manual run 

    # For now: simply use the same structure to return in the HTTP Response
    httpResponse=logMetadata 
    # Immediately pass additional info like machinenr to the span
    with tracer.start_as_current_span("Fake process logic", attributes=logMetadata):
        try:
            # Show the information also in the log text, as well as in the dimensions
            if (runNr==1):
                # Log start of the batch (which can consist of this one and possible retry runs)
                logging.info(f'{processName} started batch {batchId}', extra=logMetadata)
                logging.info(f'{processName} started run ({runNr}) {runId}', extra=logMetadata)
            else:
                logging.info(f'{processName} start retry ({runNr}) for batch {batchId} with run {runId}', extra=logMetadata)

            # Simulate processing time
            time.sleep(jobDuration)

            # Also report the duration
            if (isSuccessful):
                logging.info(f'{processName} run completed successfully',extra=logMetadata)
            else:
                # Simulate that something aborts the process
                raise Exception(f'Some fake exception for {processName}')

            # Done with all of it, return 200 (OK)
            return func.HttpResponse(json.dumps(httpResponse), mimetype="application/json", status_code=200)
        
        except Exception as error:
            # Log the exception and register that the run failed
            logging.exception(error, extra=logMetadata)
            logging.error(f'{processName} run failed.',extra=logMetadata)

            # Indicate it failed, return 500 (Server error)
            return func.HttpResponse(json.dumps(httpResponse), mimetype="application/json", status_code=500)
