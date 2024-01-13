#!/usr/bin/env python3
"""
Sample of a runbook that triggers a reload of the Events for a specific machine.
Must be started with 1 parameter: a machine number 
"""
import logging
import requests
import sys

logging.info('Runbook started')
print("Arguments: " + ','.join(sys.argv))

machinenr=""
if (len(sys.argv)==2):
    machinenr=sys.argv[1]
else:
    raise Exception("Invalid arguments. Requires 1 argument: machinenr")

print("Manually starting Events function...")
body= {
    "machine": machinenr,
    "events": {
        "manualRetry":True
    }
}

url="https://otelpoc-events-app.azurewebsites.net/api/Events"
response = requests.post(url, json=body)
print(response.text)
