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
import os
import logging
import requests
import sys
import json


def ExtractJsonRequestBodyFromWebhookdataArgument(args):
    """
    Python does not support named parameters (like PowerShell). The WEBHOOKDATA parameter will be passed in as
    one large string. But... the RequestBody sometimes contains an encoded json string. That will have
    special characters like \r\n or \" and then the parser does not understand it anymore.
    That's why there is a special routine to 
    """
    # Combine all separte commandline arguments into 1 large string.
    combinedArg=""
    for index in range(1,len(args)):
        combinedArg = combinedArg + args[index]

    # Extract the RequestBody
    # Find the opening { and then parse the remaining string to find the closing }
    requestBodyRaw=""
    bracketCounter=0
    for index in range(combinedArg.index("{",1),len(combinedArg)):
        requestBodyRaw=requestBodyRaw + combinedArg[index] 
        if combinedArg[index] == "{": bracketCounter += 1
        if combinedArg[index] == "}": bracketCounter -= 1
        if bracketCounter==0: break

    # Remove the unnecessary literal characters
    cleanRequestBodyString = requestBodyRaw.replace('\\r\\n','').replace('\\"','"')
    return json.loads(cleanRequestBodyString)


# Sample of Azure runbook in Python which is invoked in a Webhook.
try:    
    logging.info('Runbook started')
    print("Arguments: sys.argv")
#    jsonBodyJson = ExtractJsonRequestBodyFromWebhookdataArgument(sys.argv)
#    print("schemaId = " + str(jsonBodyJson['schemaId']))

    print("Manually starting Events GBR function...")

    url="https://pma5poc-eventsgbr-app.azurewebsites.net/api/EventsGBRFake"
    body='{ machine="GG77", events= { manualRetry=true } }'

    print("Posting: " + body)
    response = requests.post(url, json=body)
    response_body = response.json()

    print("Request sent! Result:")
    print(response_body)
except:
    print("Payload has an invalid structure.")

