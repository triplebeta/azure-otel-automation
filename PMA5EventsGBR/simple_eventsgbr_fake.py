import azure.functions as func
from simulation_request import SimulationRequest
import logging
import random

from azure.monitor.opentelemetry import configure_azure_monitor
from opentelemetry import trace, metrics

# NOTE: This code is not needed here since we pass the tracer from the function_app.py to avoid duplicate logs
# Avoid duplicate logging
# root_logger = logging.getLogger()
# for handler in root_logger.handlers[:]:
#     root_logger.removeHandler(handler)
# configure_azure_monitor()
# tracer = trace.get_tracer(__name__)

meter = metrics.get_meter_provider().get_meter(__name__)
metric_run_started = meter.create_counter(name="events.runs", description="Count all runs.")
metric_run_failed = meter.create_counter(name="events.runs.failed", description="Count failed runs.")
metric_run_completed = meter.create_counter(name="events.runs.failed", description="Count failed runs.")


def EventsGBRFakeSimple(req: func.HttpRequest, tracer) -> func.HttpResponse:
    logging.info(f"Extracting parameters from request...")
    params = SimulationRequest(req.get_json())

    try:
        # Immediately pass additional info like machinenr to the span
        with tracer.start_as_current_span("Processing events", attributes={"machine":params.machine_nr}):
            logging.info(f"Events started run", extra={"machine":params.machine_nr})
            metric_run_started.add(1,attributes={"machine":params.machine_nr})
            events_created_count = random.randrange(30,200)
            metric_run_completed.add(1)

        return func.HttpResponse(f"Completed processing {events_created_count} events", status_code=200)

    except Exception as error:
        logging.exception(f'Events error handled!',exc_info=error)
        logging.error(f"Events failed run", exc_info=error)
        metric_run_failed.add(1)

        # Indicate it failed, return 500 (Server error)
        return func.HttpResponse("Events failed.", mimetype="application/json", status_code=500)


