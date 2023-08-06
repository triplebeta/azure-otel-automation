from typing import List
import os
import logging
import azure.functions as func

# For using the event hub
from azure.eventhub import EventData
from azure.eventhub import EventHubConsumerClient

from azure.monitor.opentelemetry import configure_azure_monitor
from opentelemetry import trace
from opentelemetry import metrics

# Workaround (part 1/3) for Azure Functions, according to: https://learn.microsoft.com/en-us/azure/azure-monitor/app/opentelemetry-python-opencensus-migrate
from opentelemetry.context import attach, detach
from opentelemetry.trace.propagation.tracecontext import TraceContextTextMapPropagator

configure_azure_monitor()
tracer = trace.get_tracer(__name__)

# Compose the name of the event hub to use for this environment
if os.environ['APP_CONFIGURATION_LABEL'] == 'staging' or os.environ['APP_CONFIGURATION_LABEL'] == 'local':
     ehName = 'eventsgbr-staging'
else:
     ehName = 'eventsgbr'  # production

app = func.FunctionApp()

# Tasks: Simulate creating tasks when events sends a trigger.
# Cardinality can be set to "many" or to "one".
# It will log more metrics when using "many" 
@app.function_name(name="TaskerFake")
@app.event_hub_message_trigger(arg_name="myEvents", event_hub_name=ehName, cardinality="one", connection="EVENTHUB_CONNECTION_STRING") 

def TaskerFake(myEvents: func.EventHubEvent, context):
     # Workaround (part 2/3)
     functions_current_context = {
          "traceparent": context.trace_context.Traceparent,
          "tracestate": context.trace_context.Tracestate
     }
     parent_context = TraceContextTextMapPropagator().extract(
          carrier=functions_current_context
     )
     token = attach(parent_context)

     # Exception events
     try:
          with tracer.start_as_current_span("catch fake exception") as span:
               # This exception will be automatically recorded
               raise Exception("Custom exception message.")
     except Exception:
          print("Exception raised")

     with tracer.start_as_current_span("receiving event and creating tasks"):
          # Log info with some extra information in key-valye pairs
          logging.info(f'Function triggered to process a message: {myEvents.get_body().decode("utf-8")} with SequenceNumber = {myEvents.sequence_number} and Offset = {myEvents.offset}', extra={"extraField":"Value1"})

     # Workaround (part 3/3)
     token = detach(token)
