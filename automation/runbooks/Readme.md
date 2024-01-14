# Azure Automation runbooks
Some sample runbooks to show how to automate actions using Python.
A benefit of using runbooks is that all runs are tracked and runbooks can be triggered manually, by a schedule, an alert, a webhook etc...

## How to deploy
You can use the Azure Devops pipeline [deploy-runbooks-pipeline.yml](deploy-runbooks-pipeline.yml) to deploy the runbooks. This uses a PowerShell script.

It deploys the runbooks and for one of them it creates a webhook. It also deployes an alert, connected with an actionGroup and actionRules. When the alert fires, it will trigger the runbook using the webhook.

_*important:*_: you must MANUALLY assign the Contributor role to the managed identity of the automation account. Otherwise the deploy-runbooks-pipeline will fail with an exception:
```
User-Assigned Managed Identity is enabled but it does not have Contributor access to  Automation account (User-Assigned Managed Identity is enabled but it does not have  Contributor access to Automation account)
```


## Testing a runbook locally
You can easily test the runbook by running the python file from the commandline:

```
python.exe ManuallyStartEventsRun.py,TESTJE
```
You might need to create a local.settings.json file for the configuration.

## Passing parameters to a Python runbook
A runbook accepts input parameters and if you create runbook using PowerShell, you can use named parameters. However, Python runbooks do not support that so you need to parse the parameters by their position.

Runbook [ManuallyStartEventsRun.py](ManuallyStartEventsRun.py) shows how to use a parameter.

In case the runbook is started from a webhook, it's more complex because the runbook receives 1 parameter, WEBHOOKDATA, containing all the data as a json string. The runbook [MyFirstPythonRunbookForWebhook.py](MyFirstPythonRunbookForWebhook.py) shows how to handle 