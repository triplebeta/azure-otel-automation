#
# TODO Remove duplication with similar class in Events GBR
# Entity to capture details of the request to Tasks.
# Most values are optional, only the "device_id" is required
#
# {
#     "device_id": 123,  //   Number of the device to process
#     "events": {
#         "error": "Some error message"   // If set, this function will abort with this error
#     },
#     "tasks": {
#         "iterations": 3                   // Default: 1.     Number of runs to execute.
#         "success": true                   // Default: true.  Determines the result of the last request.
#         "manualRetry": true               // Default: false. If true, each retry will be started as MANUAL run
#         "error": "Some error message"     // Default: None.  If set, this function will abort with this error.
#     }
# }
# Contains also some other values:
#   batch:          <newly generated>

import random

class TasksSimulationRequest:
    def __init__(self, jsonBody):
        self.device_id = jsonBody.get('device_id')                  # For which device to run
        if (self.device_id is None): raise ValueError('Body must contain JSON with at least a value for device.')
        
        # set default, ensure the properties exist
        self.tasks_error = None
        self.tasks_iterations = 1
        self.tasks_success=True
        self.is_manual_run=False

        # if they are set, override the default value
        tasks = jsonBody.get("tasks")
        if (tasks is not None):
            if (tasks.get('iterations') is not None):
                self.tasks_iterations = int(jsonBody["tasks"]["iterations"])          # 1 for first run, 2 for first retry etc..

            if (tasks.get('success') is not None):
                self.tasks_success = bool(jsonBody["tasks"]["success"])               # True by default

            if (tasks.get('manualRetry') is not None):
                self.tasks_is_manual = bool(jsonBody["tasks"]["manualRetry"])         # true to simulate retries were done manually

            # If set, the Tasks run will fail with that error, otherwise it will succeed
            if (tasks.get('error') is not None):
                self.tasks_error = jsonBody["tasks"]["error"]

        self.tasks_duration = random.randrange(2,6,1)


