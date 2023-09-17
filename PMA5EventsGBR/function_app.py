import json
import os
import datetime
import logging
import random
import azure.functions as func

# For using the event hub
from azure.eventhub import EventData
from azure.eventhub.aio import EventHubProducerClient

# Open Telemetry
from azure.monitor.opentelemetry import configure_azure_monitor
from opentelemetry import trace, metrics
# from  applicationinsights  import  TelemetryClient

# Workaround (part 1/3) specifically for Azure Functions, according to: https://learn.microsoft.com/en-us/azure/azure-monitor/app/opentelemetry-python-opencensus-migrate
from opentelemetry.context import attach, detach
from opentelemetry.trace.propagation.tracecontext import TraceContextTextMapPropagator

configure_azure_monitor()
tracer = trace.get_tracer(__name__)

# Create metrics. unit must be one of the values from the UCUM, see: https://ucum.org/ucum
# Types of telemetry, https://www.timescale.com/blog/a-deep-dive-into-open-telemetry-metrics/
# The "observable" metrics are asynchronous. Important difference: they should NOT report delta values but absolute values. The framework will convert then them to deltas.
# Counter: delta's, only increasing
# Gauge: data you would not want to sum but might want to avg or use max.
meter = metrics.get_meter_provider().get_meter(__name__)
eventFilesProcessedCounter = meter.create_counter(name="MachinesProcessed", description="Count of batches processed for a machine.")
validEventCounter = meter.create_counter(name="ValidEvents", description="Total number of valid events created for this machine.")
invalidEventCounter = meter.create_counter(name="InvalidEvents", description="Total number of invalid events that were skipped.")
processingTimeCounter = meter.create_counter(name="ProcessingTime", unit="second", description="Total duration for creating the events for this machine.")
eventDayCoverage = meter.create_observable_gauge(name="EventDayCoverage", description="Percentage of the day for which we have full event coverage.")

# Global variable to use in async callback for metric
machinenr = "Unknown"  # Must be read from the request.

app = func.FunctionApp()

@app.route(route="EventsGBRFake", auth_level=func.AuthLevel.ANONYMOUS)
async def EventsGBRFake(req: func.HttpRequest, context) -> func.HttpResponse:
    """ For logging in Python Function Apps, see:
        https://learn.microsoft.com/en-us/azure/azure-functions/functions-reference-python?tabs=asgi%2Capplication-level&pivots=python-mode-decorators

        Events GBR simulation: pretents that a batch of events is processed
        Http POST should contain json to specify the details of the batch:
        - machinenr
        - number of lines
        - event filename
    """
    global machinenr

    # Workaround (part 2/3) to on context information.
    functions_current_context = {
        "traceparent": context.trace_context.Traceparent,
        "tracestate": context.trace_context.Tracestate
    }
    parent_context = TraceContextTextMapPropagator().extract(carrier=functions_current_context)
    token = attach(parent_context)

    # Explicitly register that this FunctionApp has a dependency on the AppService
    # Added to enable manual registration of dependencies to complete the Application Map of AppInsights
    # instrumentation_key = '1363bf29-376b-438f-b89b-52894213dd2a'
    # tc = TelemetryClient(instrumentation_key)
    # with tracer.start_as_current_span("register dependency from appService on FunctionApp") as span:
    #     tc.track_dependency(name="Events GBR (prod)", type="function_app", data=context.function_name, target="pma5poc-eventsgbr-app.azurewebsites.net", success=True, result_code=0)
    #     tc.flush()


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
            machinenr = req_body.get('machinenr')
            numberOfLines = int(req_body.get('numberOfLines'))
            eventFilename = req_body.get('eventFilename')

        if not machinenr or not numberOfLines or not eventFilename:
            return func.HttpResponse("Body must contain machinenr, numberOfEvents and eventFilename.", status_code=400)

    # machinenr value wasn't known yet at the start of the span, so set it now
    span.set_attribute("machinenr",machinenr) # Support finding the span by the machinenr


    # Assume processing will be successful
    completedSuccessfully = True
    try:
        # Immediately pass additional info like machinenr to the span
        with tracer.start_as_current_span("Processing of the events", attributes={"machinenr":machinenr}):
            logging.info(f"Processing GBR Events {numberOfLines} lines of file {eventFilename} for machine '{machinenr}...", extra={"machinenr":machinenr})

            # Introducte artifical errors or warnings.
            if numberOfLines == -1:  raise Exception("Injected error -1: Less than 100 events received. (numberOfLines == -1)")
            if numberOfLines == 200: logging.warning("Injected warning -2: Some suspicious data found. (numberOfLines == 200)")

            # Total number of events created for this machine
            # For testing we assume that for machine FQ99 1% of the events is invalid. All other eventfiles ar 100% ok.
            if machinenr=="FQ99":
                validEventsCount = numberOfLines * 0.99
                invalidEventsCount = numberOfLines - validEventsCount
            else:
                validEventsCount = numberOfLines
                invalidEventsCount = 0

            # Number of valid and invalid events
            validEventCounter.add(validEventsCount, {"machinenr": machinenr, "eventFilename": eventFilename})
            invalidEventCounter.add(invalidEventsCount, {"machinenr": machinenr, "eventFilename": eventFilename})

            logging.info(f"Processing GBR Event completed.", extra={"machinenr":machinenr})

        # Send an event to the Event Hub
        with tracer.start_as_current_span("Send trigger for tasks to Event Hub", attributes={"machinenr":machinenr}):
            logging.info(f'Sending trigger from Events GBR to Tasker for machine {machinenr}', extra={"machinenr":machinenr})
            EVENT_HUB_CONNECTION_STR = os.environ["EVENTHUB_CONNECTION_STRING"]
            producer = EventHubProducerClient.from_connection_string(EVENT_HUB_CONNECTION_STR, eventhub_name='eventsgbr') # , transport_type=TransportType.AmqpOverWebsocket
            
            async with producer:
                # Create the message for the Tasker with number of valid events.
                # In the metrics we track how many were valid / invalid.
                taskerCmd = {'machinenr': machinenr, 'timestamp': str(datetime.datetime.utcnow()), 'numberOfEvents': validEventsCount}
                jsonTaskerCmd = json.dumps(taskerCmd) # Convert the reading into a JSON string.

                # Send trigger to the tasker via Event Hub
                event_data_batch = await producer.create_batch()
                event_data_batch.add(EventData(jsonTaskerCmd))
                await producer.send_batch(event_data_batch)
                logging.info(f'Sent trigger from Events GBR to Tasker for machine {machinenr}.', extra={"machinenr":machinenr})

        # Done with all of it
        logging.info(f"Events GBR ending successfully.", extra={"machinenr":machinenr})
        return func.HttpResponse(f"Completed processing events for machine {machinenr}", status_code=200)
    
    except:
        completedSuccessfully = False
        logging.info(f"Events GBR ending unsuccessfully.", extra={"machinenr":machinenr})
    finally:
        # Workaround (part 3/3)
        token = detach(token)

        # Increase the machines_processed counter. Each Http Trigger processes 1 file of a machine.
        eventFilesProcessedCounter.add(1.0, {"machinenr": machinenr, "eventFilename": eventFilename, "numberOfLines": numberOfLines, "isSuccessful": completedSuccessfully})

        # Total duration for processsing this file. Assuming each event is 1 line. Count lines of successful and failed processed events.
        lowDuration = numberOfLines // 100
        processingDuration = random.randrange(lowDuration, lowDuration*2)  # Fake how long it takes to parse the events
        processingTimeCounter.add(processingDuration, {"machinenr": machinenr, "eventFilename": eventFilename, "numberOfLines": numberOfLines})


# Event day coverage may go up or down. Use a callback function for Async version.
def observable_up_down_counter_func():
    # This reports the current value, which will be converted to a delta internally
    # Get the coverage for this machine
    global machinenr

    #TODO Get the event file coverage here. Difficulty is that we can only compute this once everything is done.
    return (33, {"machinenr": machinenr})
