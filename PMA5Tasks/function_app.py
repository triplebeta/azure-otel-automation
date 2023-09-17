from typing import List
import json
import logging
import random
import azure.functions as func

# For using the event hub
from azure.eventhub import EventData
from azure.eventhub import EventHubConsumerClient

from azure.monitor.opentelemetry import configure_azure_monitor
from opentelemetry import trace, metrics

# Workaround (part 1/3) for Azure Functions, according to: https://learn.microsoft.com/en-us/azure/azure-monitor/app/opentelemetry-python-opencensus-migrate
from opentelemetry.context import attach, detach
from opentelemetry.trace.propagation.tracecontext import TraceContextTextMapPropagator

configure_azure_monitor()
tracer = trace.get_tracer(__name__)

meter = metrics.get_meter_provider().get_meter(__name__)
taskerTriggersProcessedSuccessfulCounter = meter.create_counter(name="TaskerRunSuccess", description="Count of successful runs for a machine.")
tasksProducedCounter = meter.create_counter(name="TasksProduced", description="Total number of tasks created for this machine.")
processingTimeCounter = meter.create_counter(name="ProcessingTime", unit="second", description="Total duration for creating the events for this machine.")


app = func.FunctionApp()

# Tasks: Simulate creating tasks when events sends a trigger.
# Cardinality can be set to "many" or to "one".
# It will log more metrics when using "many" 
@app.function_name(name="TaskerFake")
@app.event_hub_message_trigger(arg_name="myEvents", event_hub_name='eventsgbr', cardinality="one", connection="EVENTHUB_CONNECTION_STRING") 
def TaskerFake(myEvents: func.EventHubEvent, context):
     # Workaround (part 2/3)
     functions_current_context = {
          "traceparent": context.trace_context.Traceparent,
          "tracestate": context.trace_context.Tracestate
     }
     parent_context = TraceContextTextMapPropagator().extract(carrier=functions_current_context)
     token = attach(parent_context)

     try:
          # Extract info from the event hub message
          msgFromEventsGBR = myEvents.get_body().decode("utf-8")
          msgObj = json.loads(msgFromEventsGBR)

          # Collect the info from the message
          machinenr=msgObj["machinenr"]
          numberOfEvents=int(msgObj["numberOfEvents"])  # The number of valid
          timestamp=msgObj["timestamp"]

          # Any tasker job with 330 valid events in it, will FAIL.
          if numberOfEvents == 330:
               raise Exception("Injected error 330: Tasker crashed.")
          
          # Create a fake number of tasks
          numberOfTasks = (numberOfEvents / 2)  + 5
          lowDuration = numberOfTasks // 100
          processingDurationInSeconds = random.randrange(lowDuration, lowDuration*2)

          with tracer.start_as_current_span("receiving event and creating tasks") as span:
               # Support finding the span by the machinenr
               span.set_attribute("machinenr",machinenr)

               # Log info with some extra information in key-valye pairs
               logging.info(f'Function triggered to process for machine {machinenr}: {myEvents.get_body().decode("utf-8")} with SequenceNumber = {myEvents.sequence_number} and Offset = {myEvents.offset}', extra={"machinenr":machinenr})


          logging.info(f'Creating tasker metrics for machine {machinenr}.')
          taskerTriggersProcessedSuccessfulCounter.add(1.0, {"machinenr": machinenr, "numberOfTasks": numberOfTasks})

          tasksProducedCounter.add(numberOfTasks, {"machinenr": machinenr})
          # Total duration for processsing this file. Assuming each event is 1 line. Count lines of successful and failed processed events.
          processingTimeCounter.add(processingDurationInSeconds, {"machinenr": machinenr, "numberOfTasks": numberOfTasks})

     finally:        
          # Workaround (part 3/3)
          token = detach(token)
