## Deployment to Azure

The following steps help you to setup this solution on Azure. If all goes well, you will end up with one resource group containing:

* An AppService with 2 Azure Functions
* An Event Hub
* Log Analytics
* ApplicationInsights
* An Azure Automation account with some Runbooks
* A number of Workbooks
* An Alert, alert processing rule and action group
* A querypack

All of these are configured with minimal cost.

All resources can be deployed with Infrastructure as Code using Azure Devops pipelines.

1. Clone the repo & upload into your own Azure DevOps instance.

2. Configure a pipeline for these files:
    * [azure-functions-infra-pipeline.yml](../azureFunctions/infra/azure-functions-infra-pipeline.yml)
    * [appInsights-queries-functions-pipeline.yml](../appInsights/appInsights-queries-functions-pipeline.yml)
    * [deploy-runbooks-pipeline.yml](../runbooks/deploy-runbooks-pipeline.yml)
    * [deploy-events-function-pipeline.yml](../azureFunctions/EventsFunction/deploy-events-function-pipeline.yml)
    * [deploy-tasks-function-pipeline.yml](../azureFunctions/TasksFunction/deploy-tasks-function-pipeline.yml)

3. Create a variable group named otelpoc and add the following items to it:

    | Variable|Value|
    ----------|-------
    |azureServiceConnection|A Service Connection to use for deploying Azure resources. Ensure it has 2 roles: the Key Vault Administrator role so it can store the webook uri in the key vault, and the Contributor role in the subscription (or perphaps at resource group level is also sufficient) |
    |location|Location to deploy the Azure resources to, like westeurope|
    |resourceGroupName|Name of the resource group to deploy to. If this group does not exist, it will be created.|
    |subscriptionId|Id of your Azure subscription|

4. Set the permission for this variable group to ensure all pipelines can use it.

5. Ensure that the Service Connection can be used by all the pipelines and that it has the necessary permissions.

6. Execute the first pipeline. It will create most of the resources and all the prerequisites for the other pipelines.

8. Run the other pipelines to deploy the software, the Azure Monitor resources and all the other resources.

Now you are ready to start exploring the solution using the [sample scenarios](../docs/SampleScenarios.md).