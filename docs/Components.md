# Components in this showcase

Below you find a brief description of the elements of this repository. If you want to run it on you local system check out [prerequisites for local development](PrerequisitesLocalDevelopment.md). To deploy the show case to Azure you can check out [deployment to Azure](AzureDeployment.md).

## Azure functions
The core components are 2 Azure functions: Events and Tasks. Both are coded in Python (3.11) using the Python programming model V2, see [Azure Functions Python developer guide](https://learn.microsoft.com/en-us/azure/azure-functions/functions-reference-python?tabs=asgi%2Capplication-level&pivots=python-mode-decorators). All infrastructure code is written in either Bicep or Terraform.

Both use the [opentelemetry libraries](https://learn.microsoft.com/en-us/azure/azure-monitor/app/opentelemetry-enable?tabs=python) as promoted by Microsoft.
In the past it used OpenCensus but that is no longer the way to go.

### Azure Function: Events
This http-triggered function mimics some IoT device that generates events. It sends a trigger to the Event Hub to start a run of the Tasks function.
More details: [README.md](../azureFunctions/EventsFunction/README.md)

### Azure Function: Tasks
The second Azure function is there to demonstrate how to follow requests from one component to the next, using the context.
More details: [README.md](../azureFunctions/TasksFunction/README.md)


