# Proof of concept

This solution shows how you can utilize standard Azure services to monitor a solution perform common maintenance actions. It implements a working solution and deployment is automated as well.

The goal of this setup is to demonstrate the capabilities and to provide a playground to tinker with it. It can help to learn how to use these concepts.

## Components
The core components are 2 Azure functions: Events and Tasks. Both are coded in Python (3.11) using the Python programming model V2, see [Azure Functions Python developer guide](https://learn.microsoft.com/en-us/azure/azure-functions/functions-reference-python?tabs=asgi%2Capplication-level&pivots=python-mode-decorators). All infrastructure code is written in either Bicep or Terraform.

Both use the [opentelemetry libraries](https://learn.microsoft.com/en-us/azure/azure-monitor/app/opentelemetry-enable?tabs=python) as promoted by Microsoft.
In the past it used OpenCensus but that is no longer the way to go.

## Prerequisites for Azure Functions in VS Code
You should install a few plugins to be able to run the code on your local laptop:
* Python 3.11 - install from the software catalog
* [Python plugin for VS Code](https://marketplace.visualstudio.com/items?itemName=ms-python.python)
* [Azurite plugin for VS Code](https://marketplace.visualstudio.com/items?itemName=Azurite.azurite) - simulator for Azure infrastructure
* [Bicep](https://marketplace.visualstudio.com/items?itemName=ms-azuretools.vscode-bicep)- language support for the Bicep infrastructure code
* [Azure tools](https://marketplace.visualstudio.com/items?itemName=ms-vscode.vscode-node-azure-pack) - standard Microsoft plugin to work with Azure services (like functions)
* [Azure Functions](https://marketplace.visualstudio.com/items?itemName=ms-azuretools.vscode-azurefunctions) - Microsoft plugin to work with Functions
* [Azure Automation](https://marketplace.visualstudio.com/items?itemName=azure-automation.vscode-azureautomation)


### Azure Function: Events
This http-triggered function mimics some service that generates events. When it's done, it sends a trigger to the Event Hub to start a run of the Tasks function.

### Azure Function: Tasks
The second Azure function is there to demonstrate how to follow requests from one component to the next, using the context.

### Insights
