import os
import datetime
import logging
import azure.functions as func

# For using the event hub
from azure.eventhub import EventData
from azure.eventhub import EventHubProducerClient

# Configure OpenCensus for the logging to ApplicationInsights
from opencensus.trace import config_integration
from opencensus.trace.samplers import AlwaysOnSampler
from opencensus.trace.tracer import Tracer
from opencensus.extension.azure.functions import OpenCensusExtension
from opencensus.ext.azure.trace_exporter import AzureExporter
from opencensus.ext.azure import metrics_exporter
from opencensus.ext.azure.log_exporter import AzureLogHandler
from opencensus.ext.azure.log_exporter import AzureEventHandler
from opencensus.stats import aggregation as aggregation_module
from opencensus.stats import measure as measure_module
from opencensus.stats import stats as stats_module
from opencensus.stats import view as view_module
from opencensus.tags import tag_map as tag_map_module

# Enable logging to AppInsights using the OpenCensus logger
#    logger = logging.getLogger('HttpTriggerLogger')
OpenCensusExtension.configure()

# Set the name of this component in the Application Map
def callback_function_for_telemetryRoleName(envelope):
   envelope.tags['ai.cloud.role'] = 'GBR Events'

# Enable requests and logging integratioon
config_integration.trace_integrations(['logging'])
config_integration.trace_integrations(['requests'])

azureExporter=AzureExporter()
azureExporter.add_telemetry_processor(callback_function_for_telemetryRoleName)
tracer = Tracer(exporter=azureExporter, sampler=AlwaysOnSampler())

logging.basicConfig(format='%(asctime)s traceId=%(traceId)s spanId=%(spanId)s %(message)s')
logger = logging.getLogger(__name__)

# AzureLogHandler
azureLogHandler = AzureLogHandler()
azureLogHandler.add_telemetry_processor(callback_function_for_telemetryRoleName)
logger.addHandler(azureLogHandler)

# logger.warning('Before the span')
# with tracer.span(name='hello'):
#     logger.warning('In the span')
#     logger.warning('After the span')

# ===============
# All code in this block is for the sample code that sends metrics to AppInsights
stats = stats_module.stats
view_manager = stats.view_manager
stats_recorder = stats.stats_recorder

prompt_measure = measure_module.MeasureInt("prompts", "number of prompts", "prompts")
prompt_view = view_module.View("prompt view", "number of prompts", [], prompt_measure, aggregation_module.CountAggregation())
view_manager.register_view(prompt_view)
mmap = stats_recorder.new_measurement_map()
tmap = tag_map_module.TagMap()

metricsExporter = metrics_exporter.new_metrics_exporter()
view_manager.register_exporter(metricsExporter)

# ===============

app = func.FunctionApp()

@app.route(route="EventsGBRFake", auth_level=func.AuthLevel.ANONYMOUS)
def EventsGBRFake(req: func.HttpRequest, context) -> func.HttpResponse:
    """ For logging in Python Function Apps, see:
        https://learn.microsoft.com/en-us/azure/azure-functions/functions-reference-python?tabs=asgi%2Capplication-level&pivots=python-mode-decorators

        Events GBR simulation: pretents that a batch of events is processed
        Http POST should contain json to specify the details of the batch:
        - machinenr
        - number of events
        - package name
    """

    # You must use context.tracer to create spans
    with context.tracer.span("just the initialization"):
        logger.debug('Starting the EventsGBRFake function')

    # See also: https://learn.microsoft.com/en-us/azure/azure-monitor/app/opencensus-python
    # Use properties in exception logs
    with context.tracer.span("catch exception and some logging"):
        properties = {'custom_dimensions': {'key_1': 'value_1', 'key_2': 'value_2'}}
        try:
            result = 1 / 0  # generate a ZeroDivisionError
        except Exception:
            logger.exception('Captured an exception.', extra=properties)

        # Nested span to send some metrics
        with context.tracer.span("sending some metrics"):
            for _ in range(4):
                mmap.measure_int_put(prompt_measure, 1)
                mmap.record(tmap)

                # I expect the next 2 lines are just to show the metrics also in the console, not needed for AppInsights
                metrics = list(mmap.measure_to_view_map.get_metrics(datetime.datetime.utcnow()))
                print(metrics[0].time_series[0].points[0])

    # Send a customEvent. This requires that the AzureHandler is installed.
    # logger.info('Hello World Custom Event!')
    # logging.info('Test if info from EventsGBR shows up in AppInsights.')
    # logging.warning('Test if a warning from EventsGBR shows up in AppInsights');
    # logging.error('Test if an error from EventsGBR shows up in AppInsights')
    # raise ValueError('Test if this exception from EventsGBR show up in AppInsights.')

    # Send an event to the Event Hub
    # This is the admin connection string that gives you full access
    # Example from: https://github.com/Azure/azure-sdk-for-python/blob/main/sdk/eventhub/azure-eventhub/samples/sync_samples/send.py
    with context.tracer.span("sending message to Event Hub"):
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
