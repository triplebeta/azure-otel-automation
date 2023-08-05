import os
import datetime
import logging
import azure.functions as func

# For using the event hub
from azure.eventhub import EventData
from azure.eventhub import EventHubConsumerClient

from azure.monitor.opentelemetry import configure_azure_monitor
from opentelemetry import trace
from opentelemetry import metrics

configure_azure_monitor()
tracer = trace.get_tracer(__name__)

# Enable logging to AppInsights using the OpenCensus logger
#logger = logging.getLogger('HttpTriggerLogger')

# Enable requests and logging integratioon
app = func.FunctionApp()

# for logging in Python Function Apps, see:
#  https://learn.microsoft.com/en-us/azure/azure-functions/functions-reference-python?tabs=asgi%2Capplication-level&pivots=python-mode-decorators

# Tasks: Simulate creating tasks when events sends a trigger.
@app.function_name(name="TaskerFake")
@app.event_hub_message_trigger(arg_name="myEventHub", event_hub_name="eventsgbr", connection="EVENTHUB_CONNECTION_STRING") 

def TaskerFake(myEventHub: func.EventHubEvent):
     
     # Exception events
     try:
          with tracer.start_as_current_span("catch fake exception") as span:
               # This exception will be automatically recorded
               raise Exception("Custom exception message.")
     except Exception:
          print("Exception raised")

     with tracer.start_as_current_span("receiving event and creating tasks"):
          # Log info with some extra information in key-valye pairs
          logging.info('Python EventHub trigger processed an event: %s', myEventHub.get_body().decode('utf-8'), extra={"extraField":"Value1"})
