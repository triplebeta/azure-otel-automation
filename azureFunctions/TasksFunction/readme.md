# Simulator of Tasks component

## Why this simulator

By simulating the setup of 3 chained components (Events, Tasks and States), we can learn how to connect them
and which metrics and logs we need. This tasks component is triggered by an Event Hub message.

It does not actually produce any data, just metrics and log messages. And it can simulate various situations
so we can test how those are reflected in the dashboards.

## Local development
Configure your local local development environment to run the Azure functions. The workspace is setup as multi-root, meaning it is configured to support debugging more than one Function at te same time.

1. Install the [prerequisites for local development](../../README.md).

2. Also create a local.settings.json file for TasksFunction. Make sure to use the value from the **Tasks function** because the Event Hub connection string is different.

    ```json
    {
    "IsEncrypted": false,
    "Values": {
        "FUNCTIONS_WORKER_RUNTIME": "python",
        "AzureWebJobsStorage": "UseDevelopmentStorage=true",
        "OTEL_SERVICE_NAME": "Events (local)",
        "APPLICATIONINSIGHTS_CONNECTION_STRING": "<copy from config of Tasks function in Azure>",
        "EVENTHUB_CONNECTION_STRING": "<copy from config of Tasks function in Azure>"
    }
    }
    ```

3. Start the local Azure emulator.

You may need to configure the location where Azurite stores its files. I configured it to c:\temp\azurite in my setup. You can configure this in the settings of the Azurite plugin. By default it will store its files in the root of the workspace. Those files are excluded from Git and in .vscode\settings.json

Then press F1 and type **Azurite: start**

4. You can now run the Azure function on your local system by opening Run & Debug (Ctrl-Shift-D) and clicking Play for the Events function.

This will first install the dependencies from the Requirements.txt file and you should then see the endpoints that are available.

## Known issue: Event Hub checkpoint of local and Azure Tasks function get out of sync 
The local Tasks function will read from the same Event Hub as the Tasks Function on Azure but they both keep a checkpoint counter. This will cause issues since the counters will get out of sync. This results in the error 'The supplied offset '' is invalid.'.

You can fix this by manually removing the file in the storage account where the checkpoint is stored. You may use the Storage Explorer to remove that file from the local storage account of Azurite or the storage account in Azure.
