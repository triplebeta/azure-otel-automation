import logging
import azure.functions as func

# Open Telemetry
from azure.monitor.opentelemetry import configure_azure_monitor
from opentelemetry import trace, metrics

from events_function_advanced import EventsAdvancedFunction
from events_function_simple import EventsSimpleFunction

# Avoid duplicate logging
root_logger = logging.getLogger()
for handler in root_logger.handlers[:]:
    root_logger.removeHandler(handler)
configure_azure_monitor()
tracer = trace.get_tracer(__name__)


# Implement a function app with 2 endpoints
app = func.FunctionApp()

# For demo purposes: simple Function with basic functionality
# Pass in the tracer as an extra argument since it's created in this routine.
@app.route(route="EventsSimple", auth_level=func.AuthLevel.ANONYMOUS)
def EventsSimple(req: func.HttpRequest) -> func.HttpResponse:
    return EventsSimpleFunction(req, tracer)

# Much more advanced function that includes retry, error handling etc
# Pass in the tracer as an extra argument since it's created in this routine.
@app.route(route="Events", auth_level=func.AuthLevel.ANONYMOUS)
async def EventsAdvanced(req: func.HttpRequest, context) -> func.HttpResponse:
    return await EventsAdvancedFunction(req,context, tracer)