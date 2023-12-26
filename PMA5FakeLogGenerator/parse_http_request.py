import logging
from run import Run
import azure.functions as func

# Parse the HTTP POST request and return a Run object containing all the info
def extract_run_from_request(req: func.HttpRequest) -> Run:
    # Extract the machinenr from the POST request
    # Read json to get the parameter values

    logging.info(f"Extracting parameters from request...")
    try:
        req_body = req.get_json()
    except ValueError:
        pass
    else:
        processName = req_body.get('processName')           # Name of the process for which we will write log lines
        machinenr = req_body.get('machinenr')               # For which machine to run
        runDuration = int(req_body.get('runDuration'))      # Time to wait (seconds)
        isSuccessful = bool(req_body.get('isSuccessful'))   # Should the job succeed or fail
        isManualRun = bool(req_body.get('isManualRun'))     # true for manual runs 
        batchId = req_body.get('batchId')                   # Optional, only for retries: Id of the batch 
        
        if (req_body.get('runNr') is not None):
            runNr = int(req_body.get('runNr'))              # 1 for first run, 2 for first retry etc...
        else: runNr=1

    # Create a new run
    activeRun = Run(processName, machinenr, batchId, runNr, runDuration, isSuccessful, isManualRun)
    return activeRun