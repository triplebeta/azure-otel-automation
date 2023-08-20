import json
import os
import datetime
import logging
import random
from time import sleep
import azure.functions as func

# For using the event hub
from azure.eventhub import EventData, TransportType
from azure.eventhub.aio import EventHubProducerClient

# Open Telemetry
from azure.monitor.opentelemetry import configure_azure_monitor
from opentelemetry import trace, metrics
from  applicationinsights  import  TelemetryClient

# Workaround (part 1/3) for Azure Functions, according to: https://learn.microsoft.com/en-us/azure/azure-monitor/app/opentelemetry-python-opencensus-migrate
from opentelemetry.context import attach, detach
from opentelemetry.trace.propagation.tracecontext import TraceContextTextMapPropagator

configure_azure_monitor()
tracer = trace.get_tracer(__name__)

# Added to enable manual registration of dependencies to complete the Application Map of AppInsights
instrumentation_key = '1363bf29-376b-438f-b89b-52894213dd2a'
tc = TelemetryClient(instrumentation_key)

# Create metrics
meter = metrics.get_meter_provider().get_meter(__name__)
counterMachinesProcessed = meter.create_counter(name="MachinesProcessed",description="Count of batches processed for a machine.")
counterEventsCreated = meter.create_counter(name="EventsCreated", description="Total number of events created for this machine.")
counterEventCreationDuration = meter.create_counter(name="EventCreationDuration", description="Total duration for creating the events for this machine.")


app = func.FunctionApp()

@app.route(route="EventsGBRFake", auth_level=func.AuthLevel.ANONYMOUS)
async def EventsGBRFake(req: func.HttpRequest, context) -> func.HttpResponse:
    """ For logging in Python Function Apps, see:
        https://learn.microsoft.com/en-us/azure/azure-functions/functions-reference-python?tabs=asgi%2Capplication-level&pivots=python-mode-decorators

        Events GBR simulation: pretents that a batch of events is processed
        Http POST should contain json to specify the details of the batch:
        - machinenr
        - number of events
        - package name
    """

    # Workaround (part 2/3)
    functions_current_context = {
        "traceparent": context.trace_context.Traceparent,
        "tracestate": context.trace_context.Tracestate
    }
    parent_context = TraceContextTextMapPropagator().extract(carrier=functions_current_context)
    token = attach(parent_context)

    # Register that this FunctionApp has a dependency on the AppService
    tc.track_dependency(name="EventsGBRFake", data="https://pma5poc-eventsgbr-app.azurewebsites.net", type="FunctionApp trigger", target="pma5poc-eventsgbr-app", success=True, result_code=0)
    tc.flush()

    # Extract the machinenr from the POST request
    # Read json to get the parameter values
    with tracer.start_as_current_span("step 1. extract parameters from request") as span:
        if req.method != "POST": return func.HttpResponse("Must send a POST request.", status_code=400)
        try:
            req_body = req.get_json()
        except ValueError:
            pass
        else:
            machinenr = req_body.get('machinenr')
            numberOfEvents = int(req_body.get('numberOfEvents'))
            packageName = req_body.get('packageName')

        if not machinenr or not numberOfEvents or not packageName:
            return func.HttpResponse("Body must contain machinenr, numberOfEvents and packageName.", status_code=400)

        span.set_attribute("machinenr",machinenr) # Support finding the span by the machinenr
        logging.info(f"Processing {numberOfEvents} events for machine '{machinenr}' from package {packageName}.")
    
    try:
        with tracer.start_as_current_span("step 2. process the events", attributes={"machinenr":machinenr}):
            if numberOfEvents == -1: 
                raise Exception("Injected error -1: Less than 100 events received.")

            if numberOfEvents == -2:
                logging.warning("Injected warning -2: Some suspicious data found.")


        # Proceed with normal handling of the events
        # Wait for some seconds, based on the numberOfEvents.
        # Waiting time is always a number of seconds.
        # Example:
        #   200 events --> 2 tot 4 seconden
        #   900 events --> 9 tot 18 seconden
        lowDuration = numberOfEvents // 100
        processingDuration = random.randrange(lowDuration, lowDuration*2)
        logging.info(f"GBR Event processing started (duration: {processingDuration}).")

        # Send an event to the Event Hub
        with tracer.start_as_current_span("send trigger for tasks to Event Hub"):
            # Compose the name of the event hub to use for this environment
            if os.environ['APP_CONFIGURATION_LABEL'] == 'production':
                EVENT_HUB_NAME = 'eventsgbr'         # for production
            else:
                EVENT_HUB_NAME = 'eventsgbr-staging' # for testing
            
            EVENT_HUB_CONNECTION_STR = os.environ["EVENTHUB_CONNECTION_STRING"]
            producer = EventHubProducerClient.from_connection_string(EVENT_HUB_CONNECTION_STR, eventhub_name=EVENT_HUB_NAME) # , transport_type=TransportType.AmqpOverWebsocket
            
            async with producer:
                # event_data = "this is the first message"
                event_data_batch = await producer.create_batch()
                logging.debug("Event batch created.")

                # Create the message for the Tasker.
                # Some other samples:  'uv': random.random(), 'humidity': random.randint(70, 100)
                taskerCmd = {'machinenr': machinenr, 'timestamp': str(datetime.datetime.utcnow()), 'numberOfEvents': numberOfEvents}
                jsonTaskerCmd = json.dumps(taskerCmd) # Convert the reading into a JSON string.

                # Send the command to the tasker
                event_data_batch.add(EventData(jsonTaskerCmd))
                logging.debug(f"Sending batch to event hub {EVENT_HUB_NAME}...")
                await producer.send_batch(event_data_batch)
                logging.info(f'Successfully delivered batch to event hub for machine {machinenr}.')

        with tracer.start_as_current_span("compose metrics"):
            logging.debug("Creating metrics...")

            # Increase the machines_processed counter
            counterMachinesProcessed.add(1.0, {"machinenr": machinenr})  # Each Http Trigger is for 1 machine
            logging.debug("Created metric: MachinesProcessed")

            # Total number of events created for this machine
            counterEventsCreated.add(numberOfEvents, {"machinenr": machinenr, "duration": processingDuration})
            logging.debug("Created metric: EventsCreated")

            # Total duration for creating the events for this machine.
            counterEventCreationDuration.add(processingDuration, {"machinenr": machinenr})
            logging.debug("Created metric: EventCreationDuration")

        # Just send some response
        return func.HttpResponse(f"Completed processing events for machine {machinenr}", status_code=200)
    
    finally:
        # Workaround (part 3/3)
        logging.debug("Detaching token...")
        token = detach(token)
        logging.debug("Detached token.")



# Time-triggered function, just for some testing.
# @app.schedule(schedule="0 0 */1 * * *", arg_name="myTimer", run_on_startup=True,
#               use_monitor=False) 
# def SchedulerFiveMinutesFake(myTimer: func.TimerRequest) -> None:
#     utc_timestamp = datetime.datetime.utcnow().replace(
#         tzinfo=datetime.timezone.utc).isoformat()
#
#     if myTimer.past_due:
#         logging.info('The timer is past due!')
#
#     logging.info('This is the SchedulerFiveMinutesFake timer job that ran at %s', utc_timestamp)
