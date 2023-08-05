import datetime
import logging
import azure.functions as func

# For using the event hub
from azure.eventhub import EventData
from azure.eventhub import EventHubConsumerClient

# Configure OpenCensus for the logging to ApplicationInsights
from opencensus.trace import config_integration
from opencensus.ext.azure import metrics_exporter
from opencensus.extension.azure.functions import OpenCensusExtension
from opencensus.ext.azure.log_exporter import AzureLogHandler
from opencensus.stats import aggregation as aggregation_module
from opencensus.stats import measure as measure_module
from opencensus.stats import stats as stats_module
from opencensus.stats import view as view_module
from opencensus.tags import tag_map as tag_map_module

# Enable logging to AppInsights using the OpenCensus logger
logger = logging.getLogger('HttpTriggerLogger')
logger.addHandler(AzureLogHandler())
OpenCensusExtension.configure()

# Enable requests and logging integratioon
config_integration.trace_integrations(['logging'])
config_integration.trace_integrations(['requests'])
app = func.FunctionApp()

# for logging in Python Function Apps, see:
#  https://learn.microsoft.com/en-us/azure/azure-functions/functions-reference-python?tabs=asgi%2Capplication-level&pivots=python-mode-decorators

# Tasks: Simulate creating tasks when events sends a trigger.
@app.function_name(name="TaskerFake")
@app.event_hub_message_trigger(arg_name="myEventHub", event_hub_name="eventsgbr", connection="EVENTHUB_CONNECTION_STRING") 

def TaskerFake(myEventHub: func.EventHubEvent, context):
     
     with context.tracer.span("receiving event and creating tasks"):
          logging.info('Python EventHub trigger processed an event: %s', myEventHub.get_body().decode('utf-8'))
    

