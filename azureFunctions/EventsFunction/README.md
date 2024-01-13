# Events function

The function does not have actual business logic, it is just an empty shell that implements only emits the logging and metrics that such a service should emit.

## How to start
You can activate this function using a tool like Postman or the [Thunder Client plugin for VS Code](https://marketplace.visualstudio.com/items?itemName=rangav.vscode-thunder-client).

You can find a collection of requests for the Thunder client in [thunder-collection_EventsFunctions.json](/thunder-collection_EventsFunctions.json). It contains several requests. Each triggers a different behavior in the functions, leading to different log lines and metrics.  

