#!/usr/bin/env python3
"""
Processes a webhook sent from an Azure alert.

This Azure Automation sample runbook runs on Azure to process an alert sent
through a webhook. It converts the RequestBody into a Python object
by loading the json string sent in.

Changelog:
    2018-09-01 AutomationTeam:
    -initial script

"""
import logging
import requests
import sys


# Sample of Azure runbook in Python which is invoked in a Webhook.
logging.info('Runbook started')
print("Arguments: " + ','.join(sys.argv))

machinenr=""
if (len(sys.argv)==2):
    machinenr=sys.argv[1]
else:
    raise Exception("Invalid arguments. Requires 1 argument: machinenr")

print(f"Manually starting Events GBR function for machine {machinenr}...")
body= {
    "machine": machinenr,
    "events": {
        "manualRetry":True
    }
}

url="https://pma5poc-eventsgbr-app.azurewebsites.net/api/EventsGBRFake"
response = requests.post(url, json=body)
print(response.text)
