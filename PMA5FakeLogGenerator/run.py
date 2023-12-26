import uuid
import random

# Entity to capture details of a run
# Most values are optional, only the "machine" is required
# Defaults
#   batch:          <newly generated>
#   duration:       value between 2 and 6 seconds
#   iteration:      1      (if not specified, assume it's the first run of the batch) 
#   manual:         false  (set to true for runs that were started manually) 
#   error:          None   (successful run)
class Run:
    # Factory method
    @staticmethod
    def create(json: str):
        machine_nr = json.get('machine')                  # For which machine to run
        if (machine_nr is None): raise ValueError('Body must contain JSON with at least a value for machine.')

        if (json.get('duration') is not None):
            run_duration = int(json.get('duration'))      # Time to wait (seconds)
        else: run_duration = random.randrange(2,6,1)      # default

        error_text = json.get('error')                    # If set, the run will fail with that error, otherwise it will succeed

        if (json.get('manual') is not None):
            is_manual_run = bool(json.get('manual'))      # true for manual runs 
        else: is_manual_run=False  # default

        if (json.get('iteration') is not None):
            iteration = int(json.get('iteration'))          # 1 for first run, 2 for first retry etc..
        else: iteration = 1  # default

        # Check that batch and iteration are consistent
        if (iteration==1):
            batch_id = 'batch-' + uuid.uuid4().hex
        else:
            if (json.get('batch') is not None):
                batch_id = json.get('batch')                 # Optional, only for retries: Id of the batch 
            else:
                raise ValueError('If iteration is 1, you cannot specify a value for "batch" since it will be generated.')

        # Create a new run
        return Run(machine_nr, batch_id, iteration, run_duration, error_text, is_manual_run)


    def __init__(self, machinenr: str, batch_id: int, iteration: int, run_duration: int, error_text:str, is_manual_run):
         # Unique identifier for each run
        self.run_id = 'run-'+uuid.uuid4().hex

        self.machine_nr = machinenr
        self.duration = run_duration
        self.iteration = iteration
        self.is_manual_run = is_manual_run
        self.error = error_text
        self.batch_id = batch_id

        # For convenience, define a list of all the attributes to add as dimensions for a trace or metric.
        # Include is_manual_run only if it's a manual run
        self.metadata={"machine":self.machine_nr, "batch_id":self.batch_id, "run_id":self.run_id, "iteration":self.iteration}
        if (self.is_manual_run):
            self.label = "manual" 
            self.metadata["manual"]=self.is_manual_run  # Only add this if it's a manual run 
        else:
            self.label = str(self.iteration)