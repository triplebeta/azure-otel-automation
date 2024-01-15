# Components
If you run all the pipelines you will have a set of components. Here is a description of each component and each component has more details in its own README.md file.

## Azure functions
The core components are 2 Azure functions: Events and Tasks. Both are coded in Python (3.11) using the Python programming model V2, see [Azure Functions Python developer guide](https://learn.microsoft.com/en-us/azure/azure-functions/functions-reference-python?tabs=asgi%2Capplication-level&pivots=python-mode-decorators). All infrastructure code is written in either Bicep or Terraform.

Both use the [opentelemetry libraries](https://learn.microsoft.com/en-us/azure/azure-monitor/app/opentelemetry-enable?tabs=python) as promoted by Microsoft.
In the past it used OpenCensus but that is no longer the way to go.

### Azure Function: Events
This http-triggered function mimics some service that generates events. When it's done, it sends a trigger to the Event Hub to start a run of the Tasks function.
More details: [README.md](azureFunctions/EventsFunction/README.md)

### Azure Function: Tasks
The second Azure function is there to demonstrate how to follow requests from one component to the next, using the context.
More details: [README.md](azureFunctions/TasksFunction/README.md)

