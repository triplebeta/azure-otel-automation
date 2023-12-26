import uuid
from typing import Union

# Entity to capture details of a run 
class Run:
    def __init__(self, processName:str, machinenr: str, batchId: Union[int , type(None)], runNr: int, runDuration: int, isSuccessful:Union[bool, type(None)], isManualRun: Union[bool, type(None)]):
        # Unique identifier for each run
        self.processName = processName
        self.runId = 'run-'+uuid.uuid4().hex
        self.machinenr = machinenr
        self.runDuration = runDuration
        self.runNr = runNr
        self.runLabel = str(runNr)
        self.is_retry = (self.runNr>1)
        self.is_manual_run = (isManualRun is not None and isManualRun)
        self.is_successful = (isSuccessful is not None and isSuccessful)

        # Generate an it do use for correlating all runs.
        self.batchId=batchId
        if (self.batchId=="" or self.batchId is None):
            self.is_new_batch=True
            self.batchId = 'batch-' + uuid.uuid4().hex
        else:
            self.is_new_batch=False

        # For convenience, define a list of all the attributes to add as dimensions for a trace or metric.
        self.logMetadata={"machinenr":self.machinenr, "batchId":self.batchId, "runId":self.runId, "runNr":self.runNr}
        if (self.is_manual_run):
            self.runLabel = "manual" 
            self.logMetadata["isManualRun"]=self.is_manual_run  # Only add this if it's a manual run 

    def is_valid(self) -> bool:
        missing_fields = not self.machinenr or not self.processName or not self.runDuration
        return not missing_fields