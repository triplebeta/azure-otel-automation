import json
import os
import datetime
import logging
import random
from time import sleep
import azure.functions as func

# For using the event hub
from azure.eventhub import EventData
from azure.eventhub.aio import EventHubProducerClient
#from azure.eventhub import EventHubProducerClient# For using the event hub
from azure.eventhub import EventHubConsumerClient

from azure.monitor.opentelemetry import configure_azure_monitor
from opentelemetry import trace
from opentelemetry import metrics

# Workaround (part 1/3) for Azure Functions, according to: https://learn.microsoft.com/en-us/azure/azure-monitor/app/opentelemetry-python-opencensus-migrate
from opentelemetry.context import attach, detach
from opentelemetry.trace.propagation.tracecontext import TraceContextTextMapPropagator

configure_azure_monitor()
tracer = trace.get_tracer(__name__)

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

    # Extract the machinenr from the POST request
    # Read json to get the parameter values
    with tracer.start_as_current_span("step 1. extract parameters from request") as span:
        if req.method != "POST": return func.HttpResponse("Must send a POST request.", status_code=400)
        try:
#            myBody = json.loads(str(req.content, "utf-8"))
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
#        sleep(processingDuration)
        logging.info("GBR Event processing completed.")

        # Send an event to the Event Hub
        with tracer.start_as_current_span("send trigger for tasks to Event Hub"):
            # Compose the name of the event hub to use for this environment
            if os.environ['APP_CONFIGURATION_LABEL'] == 'production':
                EVENT_HUB_NAME = 'eventsgbr'  # production
            else:
                EVENT_HUB_NAME = 'eventsgbr-staging'

            EVENT_HUB_CONNECTION_STR = os.environ["EVENTHUB_CONNECTION_STRING"]
            producer = EventHubProducerClient.from_connection_string(EVENT_HUB_CONNECTION_STR, eventhub_name=EVENT_HUB_NAME)
            
            async with producer:
                # event_data = "this is the first message"
                event_data_batch =  await producer.create_batch()

                # Create the message for the Tasker.
                # Some other samples:  'uv': random.random(), 'humidity': random.randint(70, 100)
                taskerCmd = {'machinenr': machinenr, 'timestamp': str(datetime.datetime.utcnow()), 'numberOfEvents': numberOfEvents}
                jsonTaskerCmd = json.dumps(taskerCmd) # Convert the reading into a JSON string.

                # Send the command to the tasker
                event_data_batch.add(EventData(jsonTaskerCmd))
                producer.send_batch(event_data_batch)


        with tracer.start_as_current_span("compose metrics"):
            # Increase the machines_processed counter
            meter = metrics.get_meter_provider().get_meter(__name__)
            counter = meter.create_counter(name="MachinesProcessed",description="Count of batches processed for a machine.")
            counter.add(1.0, {"machinenr": machinenr})  # Each Http Trigger is for 1 machine

            # Total number of events created for this machine
            counter = meter.create_counter(name="EventsCreated", description="Total number of events created for this machine.")
            counter.add(numberOfEvents, {"machinenr": machinenr, "duration": processingDuration})

            # Total duration for creating the events for this machine.
            counter = meter.create_counter(name="EventCreationDuration", description="Total duration for creating the events for this machine.")
            counter.add(processingDuration, {"machinenr": machinenr})

        # Send a customEvent. This requires that the AzureHandler is installed.
        # logger.info('Hello World Custom Event!')
        # logging.info('Test if info from EventsGBR shows up in AppInsights.')
        # logging.warning('Test if a warning from EventsGBR shows up in AppInsights');
        # logging.error('Test if an error from EventsGBR shows up in AppInsights')
        # raise ValueError('Test if this exception from EventsGBR show up in AppInsights.')

        # Just send some response
        return func.HttpResponse(f"Completed processing events for machine {machinenr}", status_code=200)
    
    finally:
        # Workaround (part 3/3)
        token = detach(token)



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
