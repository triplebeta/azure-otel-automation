#
# This is a simple version of the full function
#

import azure.functions as func
from simulation_request import SimulationRequest
import logging
import random
import json
import os


# For using the event hub
from azure.eventhub import EventData
from azure.eventhub.aio import EventHubProducerClient

# Open telemetry packages
from azure.monitor.opentelemetry import configure_azure_monitor
from opentelemetry import metrics

# Azure Functions specific workaround (part 1/3) for Python opentelemetry.
# For details check out: https://learn.microsoft.com/en-us/azure/azure-monitor/app/opentelemetry-python-opencensus-migrate
from opentelemetry.context import attach, detach
from opentelemetry.trace.propagation.tracecontext import TraceContextTextMapPropagator

# NOTE: This code is not needed here since we pass the tracer from the function_app.py to avoid duplicate logs
# Avoid duplicate logging
# root_logger = logging.getLogger()
# for handler in root_logger.handlers[:]:
#     root_logger.removeHandler(handler)
# configure_azure_monitor()
# tracer = trace.get_tracer(__name__)


# Create metrics. unit must be one of the values from the UCUM, see: https://ucum.org/ucum
# Types of telemetry, https://www.timescale.com/blog/a-deep-dive-into-open-telemetry-metrics/
meter = metrics.get_meter_provider().get_meter(__name__)
metric_run = meter.create_counter(name="events.runs", description="Count all runs.")
metric_run_failed = meter.create_counter(name="events.runs.failed", description="Count failed runs.")
metric_run_completed = meter.create_counter(name="events.runs.completed", description="Count successfully completed runs.")
metric_events_count = meter.create_counter(name="events.count", description="Count of successfully created events.")

#
# This is the default one, so it will expose endpoint /api/Events
#
async def EventsAdvancedFunction(req: func.HttpRequest, context, tracer) -> func.HttpResponse:
    """ For logging in Python Function Apps, see:
        https://learn.microsoft.com/en-us/azure/azure-functions/functions-reference-python?tabs=asgi%2Capplication-level&pivots=python-mode-decorators

        Events GBR simulation: pretents that a batch of events is processed
        Http POST should contain json to specify the details for this function:
        {
            "machine": 123,  //   Number of the machine to process
            "events": {
                "error": "Some error message"   // If set, this function will abort with this error
            }
        }
        Next to that it can contain instructions for the next job (Tasks)
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
    with tracer.start_as_current_span("Parse request") as span:
        logging.info(f"Extracting parameters from request...")
        if req.method != "POST": return func.HttpResponse("Must send a POST request.", status_code=400)
        try:
            jsonBody = req.get_json()
        except ValueError:
            pass
        else:
            params = SimulationRequest(jsonBody)

        if not params.machine_nr: return func.HttpResponse("Body must contain machine.", status_code=400)

    # Compose metadata for the loglines and metrics
    metadata={"machine":params.machine_nr}
    if (params.events_is_manual): metadata["manual"]=True  # Only add this if it's a manual run 

    # Assume processing will be successful
    try:
        # Immediately pass additional info like machinenr to the span
        with tracer.start_as_current_span("Processing events", attributes=metadata):
            logging.info(f"Events started run", extra=metadata)
            metric_run.add(1,attributes=metadata)

            # If an error is set, raise it to abort this run. There will be no trigger for Tasks.
            if (params.events_error_text is not None):
                raise Exception(params.events_error_text)

            # When successful, update metrics and logs
            events_created_count = random.randrange(30,200)
            metric_events_count.add(events_created_count,attributes=metadata)

        # Send an event to the Event Hub
        with tracer.start_as_current_span("Send trigger for tasks to Event Hub", attributes=metadata):
            logging.info(f'Sending trigger from Events to Tasker', extra=metadata)
            EVENT_HUB_CONNECTION_STR = os.environ["EVENTHUB_CONNECTION_STRING"]
            producer = EventHubProducerClient.from_connection_string(EVENT_HUB_CONNECTION_STR, eventhub_name='events') # , transport_type=TransportType.AmqpOverWebsocket
            
            async with producer:
                # Create the message for the Tasker with number of valid events.
                # TODO Add Start and End to the message, and # of events
                taskerCmd = { "machine": params.machine_nr, "tasks": { "iterations":params.tasks_iterations, "success": params.tasks_success, "manualRetry": params.is_manual_run, "error": params.tasks_error}  }
                jsonTaskerCmd = json.dumps(taskerCmd)

                # Send trigger to the tasker via Event Hub
                event_data_batch = await producer.create_batch()
                event_data_batch.add(EventData(jsonTaskerCmd))
                await producer.send_batch(event_data_batch)
                logging.info(f'Sent trigger from Events to Tasker', extra=metadata)

        # Done with all of it
        metric_run_completed.add(1,attributes=metadata)
        metadata["events_created"] = events_created_count
        metadata["duration"] = params.tasks_duration
        logging.info(f"Events completed run", extra=metadata)
        return func.HttpResponse(f"Completed processing {events_created_count} events", status_code=200)
    
    except Exception as error:
        # Log the exception (which includes the traceback)
        # On the span, set record_exception=False because we handle it here and include more info
        logging.exception(f'Events error handled!',exc_info=error, extra=metadata)
        logging.error(f"Events failed run", exc_info=error, extra=metadata)
        metric_run_failed.add(1,attributes=metadata)

        # Indicate it failed, return 500 (Server error)
        return func.HttpResponse("Events failed.", mimetype="application/json", status_code=500)

    finally:
        # Workaround (part 3/3)
        token = detach(token)