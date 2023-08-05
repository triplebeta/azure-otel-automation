import os
import datetime
import logging
import azure.functions as func

# For using the event hub
from azure.eventhub import EventData
from azure.eventhub import EventHubProducerClient# For using the event hub
from azure.eventhub import EventData
from azure.eventhub import EventHubConsumerClient

from azure.monitor.opentelemetry import configure_azure_monitor
from opentelemetry import trace
from opentelemetry import metrics

configure_azure_monitor()
tracer = trace.get_tracer(__name__)

app = func.FunctionApp()

@app.route(route="EventsGBRFake", auth_level=func.AuthLevel.ANONYMOUS)
def EventsGBRFake(req: func.HttpRequest) -> func.HttpResponse:
    """ For logging in Python Function Apps, see:
        https://learn.microsoft.com/en-us/azure/azure-functions/functions-reference-python?tabs=asgi%2Capplication-level&pivots=python-mode-decorators

        Events GBR simulation: pretents that a batch of events is processed
        Http POST should contain json to specify the details of the batch:
        - machinenr
        - number of events
        - package name
    """

    # You must use context.tracer to create spans
    with tracer.start_as_current_span("just the initialization") as span:
        logging.debug('Starting the EventsGBRFake function')

    # See also: https://learn.microsoft.com/en-us/azure/azure-monitor/app/opencensus-python
    # Use properties in exception logs
    with tracer.start_as_current_span("catch exception and some logging"):
#        properties = {'custom_dimensions': {'key_1': 'value_1', 'key_2': 'value_2'}}
        try:
            result = 1 / 0  # generate a ZeroDivisionError
        except Exception:
            logging.exception('Captured an exception.', extra={'key_1': 'value_1', 'key_2': 'value_2'})

        # Nested span to send some metrics
        # with context.tracer.span("sending some metrics"):
        #     for _ in range(4):
        #         mmap.measure_int_put(prompt_measure, 1)
        #         mmap.record(tmap)

        #         # I expect the next 2 lines are just to show the metrics also in the console, not needed for AppInsights
        #         metrics = list(mmap.measure_to_view_map.get_metrics(datetime.datetime.utcnow()))
        #         print(metrics[0].time_series[0].points[0])

    # Send a customEvent. This requires that the AzureHandler is installed.
    # logger.info('Hello World Custom Event!')
    # logging.info('Test if info from EventsGBR shows up in AppInsights.')
    # logging.warning('Test if a warning from EventsGBR shows up in AppInsights');
    # logging.error('Test if an error from EventsGBR shows up in AppInsights')
    # raise ValueError('Test if this exception from EventsGBR show up in AppInsights.')

    # Send an event to the Event Hub
    # This is the admin connection string that gives you full access
    # Example from: https://github.com/Azure/azure-sdk-for-python/blob/main/sdk/eventhub/azure-eventhub/samples/sync_samples/send.py
    with tracer.start_as_current_span("sending message to Event Hub"):
        EVENT_HUB_CONNECTION_STR = os.environ["EVENTHUB_CONNECTION_STRING"]
        EVENT_HUB_NAME = "eventsgbr"
        producer = EventHubProducerClient.from_connection_string(EVENT_HUB_CONNECTION_STR, eventhub_name=EVENT_HUB_NAME)
        
        # event_data = "this is the first message"
        event_data_batch = producer.create_batch()
        event_data_batch.add(EventData('Single message from GBR Events'))
        with producer:
            producer.send_batch(event_data_batch)

    # Just send some response
    return func.HttpResponse("Hello from GBR Events function!", status_code=200)


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
