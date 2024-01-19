#!/usr/bin/env python3
"""
Sample of a runbook that triggers a reload of the Events for a specific device.
Must be started with 1 parameter: a device_id 
"""
import logging
import requests
import sys

logging.info('Runbook started')
print("Arguments: " + ','.join(sys.argv))

device_id=""
if (len(sys.argv)==2):
    device_id=sys.argv[1]
else:
    raise Exception("Invalid arguments. Requires 1 argument: device_id")

print("Manually starting Events function...")
body= {
    "device_id": device_id,
    "events": {
        "manualRetry":True
    }
}

url="https://otelpoc-events-app.azurewebsites.net/api/Events"
response = requests.post(url, json=body)
print(response.text)
