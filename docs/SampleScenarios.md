# Sample scenarios

To start a scenario you send an http POST request to the Events function. You can use the following sample payloads to run the sample scenarios. You must also send the following header:  Content-Type: application/json 

Each of samples executes a different paths in the code, some are successful, others are intended to fail. With each scenario, the Functions produce trace messages and metrics that we use for the other samples such as the Query packs, Workbooks and Alerts.

TIP: Each sample uses its own value for device_id. This makes it easy to relate the log lines to a scenario when using Log Analytics.

## Requests

### 1. Happy day scenario

Simulates a device that successfully sends one or more events and the Task is executed as well. This might be as simple as a user switching on the light using lightswitch with device_id AA11.

It runs the Events function for device AA11 without injecting any errors. That will post a message to the Event Hub for the Tasks function. The Tasks function also succeed without any retries.

```json
{
    "device_id": "AA11"
}
```

### 2. Events for BB22 ok, Tasks 1st run fails, 2nd run succeeds

Switch on the light using device BB22. Events function is successful but instructs Tasks to fail its first run and succeed in the 2nd run.

By specifying the error text and iterations, the Tasks will raise an exception with the given text.

```json
{
    "device_id": "BB22",
    "tasks": {
        "iterations": 2,
        "error": "Lightbulb did not respond"
    }
}
```

### 3. Events for CC33 ok, Tasks 3 runs fail

Same as previous but Tasks will fail 3 times. Since the Tasks retries at most 2 times, failing 3 times means that the batch failed permanently.

So in terms of the first scenario, the light will remain off.

```json
{
    "device_id": "CC33",
    "tasks": {
        "iterations": 3,
        "success": false,
    "error": "Failed to connect to lightbulb"
    }
}
```

### 4. Events for DD44 ok, Tasks 1 run fails

Events succeeds but Tasks fails in the first iteration and for some reason does not retry. This simulates a failure of the Controller that handles the Event Hub trigger.

```json
{
    "device_id": "DD44",
    "tasks": {
        "iterations": 1,
        "success": false,
        "error": "Crash of Tasks"
    }
}
```

### 5. Events for EE55 ok, Tasks 1 run fails , manual retry succeeds

Events suceeds but Tasks crashes. Then it triggers a manual retry of the task (thing: reset of the Controller). This successfully executes the task (so the light is switched on).

In the telemetry you can see this manual intervention because it adds an extra attribute in the log ("manual").

```json
{
    "device_id": "EE55",
    "tasks": {
        "iterations": 2,
        "manualRetry": true,
        "success": true,
        "error": "Crash of Tasks"
    }
}
```

### 6. Events for FF66 fails

Simulate a failure of the events function, no message will be sent to the Event Hub.

```json
{
    "device_id": "FF66",
    "events": {
        "error": "No connectivity"
    }
}
```
