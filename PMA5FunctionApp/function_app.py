import datetime
import logging
import azure.functions as func

from opencensus.extension.azure.functions import OpenCensusExtension
logger = logging.getLogger('HttpTriggerLogger')
OpenCensusExtension.configure()


app = func.FunctionApp()

# for logging in Python Function Apps, see:
#  https://learn.microsoft.com/en-us/azure/azure-functions/functions-reference-python?tabs=asgi%2Capplication-level&pivots=python-mode-decorators

# Events GBR simulation: pretents that a batch of events is processed
# Http POST should contain json to specify the details of the batch:
#   - machinenr
#   - number of events
#   - package name
@app.route(route="EventsGBRFake", auth_level=func.AuthLevel.ANONYMOUS)
def EventsGBRFake(req: func.HttpRequest, context) -> func.HttpResponse:
    logger = logging.getLogger('HttpTriggerLogger')

    # You must use context.tracer to create spans
    with context.tracer.span("parent"):
        logger.info('Message from HttpTrigger using the OpenCensus logger.info using a context.')

#    logging.info('Test if info shows up in AppInsights.')
#    logging.warning('Test if a warning shows up in AppInsights');
#    logging.error('Test if an error shows up in AppInsights')
#    raise ValueError('Test if this exception show up in AppInsights.')

    name = req.params.get('name')
    if not name:
        try:
            req_body = req.get_json()
        except ValueError:
            pass
        else:
            name = req_body.get('name')

    if name:
        return func.HttpResponse(f"Hello, {name}. This HTTP triggered function executed successfully.")
    else:
        return func.HttpResponse(
             "This HTTP triggered function executed successfully. Pass a name in the query string or in the request body for a personalized response.",
             status_code=200
        )


# Simulate the tasker
@app.schedule(schedule="0 0 */1 * * *", arg_name="myTimer", run_on_startup=True,
              use_monitor=False) 
def TaskerFake(myTimer: func.TimerRequest) -> None:
    utc_timestamp = datetime.datetime.utcnow().replace(
        tzinfo=datetime.timezone.utc).isoformat()

    if myTimer.past_due:
        logging.info('The timer is past due!')

    logging.info('Python timer trigger function ran at %s', utc_timestamp)
