# Tasks function

The Tasks Functions shows how you can receive information from another Azure Function (or any other resource) and correlate the trace messages of those components. It does not have any real business logic but implements some logic to simulate some scenarios.

* It can be instructed to succeed or fail.
* It supports doing up to 2 retries after a failed run.
* It supports doing a manual retry.

Each run of the function emits some trace messages, like starting/ending a batch and start/end of each run. It is those traces that we are after, we need them to showcase the queries and health score.

To invoke the Tasks and execute a specific scenario you need to invoke the Events function. [Here you can find](../EventsFunction/README.md) more information of how to do this and some sample scenarios.

## Local development

Configure your local local development environment to run the Azure functions. The workspace is setup as multi-root, meaning it is configured to support debugging more than one Function at te same time.

This local setup uses the ApplicationInsights and EventHub on Azure so you must first deploy the solution to Azure, or setup your own Event Hub and ApplicationInsights instance.

1. Install the [prerequisites for local development](../../README.md).

2. Also create a local.settings.json file for TasksFunction. Make sure to use the value from the **Tasks function** because the Event Hub connection string is different.

    ```json
    {
        "IsEncrypted": false,
        "Values": {
            "FUNCTIONS_WORKER_RUNTIME": "python",
            "AzureWebJobsStorage": "UseDevelopmentStorage=true",
            "OTEL_SERVICE_NAME": "Tasks (local)",
            "APPLICATIONINSIGHTS_CONNECTION_STRING": "<copy from config of Tasks function in Azure>",
            "EVENTHUB_CONNECTION_STRING": "<copy from config of Tasks function in Azure>"
        }
    }
    ```

3. Create a Python Virtual Environment for this function:
    * Press F1
    * Python: Create environment
    * Choose Venv - create a virtual environment directory .venv
    * Choose the Tasks Function
    * Choose Python 3.11
    * Dependencies to install: choose the Requirements.txt file
    And confirm with OK so that it would be the follow

4. Start the local Azure emulator.

    You may need to configure the location where Azurite stores its files. I configured it to c:\temp\azurite in my setup. You can configure this in the settings of the Azurite plugin. By default it will store its files in the root of the workspace. Those files are excluded from Git and in .vscode\settings.json

    Then press F1 and type **Azurite: start**

5. You can now run the Azure function on your local system by opening Run & Debug (Ctrl-Shift-D) and clicking Play for the Events function.

This will first install the dependencies from the Requirements.txt file and you should then see the endpoints that are available.

## Known issues

### Event Hub checkpoint of local and Azure Tasks function get out of sync

The local Tasks function will read from the same Event Hub as the Tasks Function on Azure but they both keep a checkpoint counter. This will cause issues since the counters will get out of sync. This results in the error 'The supplied offset '' is invalid.'.

You can fix this by manually removing the file in the storage account where the checkpoint is stored. You may use the Storage Explorer to remove that file from the local storage account of Azurite or the storage account in Azure.
