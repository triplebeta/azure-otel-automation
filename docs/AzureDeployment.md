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
    * [azure-runbooks-pipeline.yml](../automation/infra/azure-runbooks-pipeline.yml)
    * [deploy-events-function-pipeline.yml](../azureFunctions/EventsFunction/deploy-events-function-pipeline.yml)
    * [deploy-tasks-function-pipeline.yml](../azureFunctions/TasksFunction/deploy-tasks-function-pipeline.yml)

    * [deploy-runbooks-pipeline.yml](../automation/runbooks/deploy-runbooks-pipeline.yml)

3. Create a variable group named otelpoc and add the following items to it:

    | Variable|Value|
    ----------|-------
    |adoAccountName| name of your Azure Devops accoun, the first part in the url after dev.azure.com|
    |AdoPat|Personal Access Token, needed to setup the Automation account [as described here](https://github.com/jordanbean-msft/automation-ado).|
    |adoRepositoryName|Name of this repository that contains the code and runbooks|
    |azureServiceConnection|A Service Connection to use for deploying Azure resources. Ensure it has sufficient priviledges.|
    |location|Location to deploy the Azure resources to, like westeurope|
    |resourceGroupName|Name of the resource group to deploy to. If this group does not exist, it will be created.|
    |subscriptionId|Id of your Azure subscription|
    |tenantId|Id of the tenant of your Azure subscription|

4. Set the permission to ensure all pipelines can use this variable group.

5. Ensure that the Service Connection can be used by all the pipelines.

6. Execute the first 3 pipelines in the order as show above. After running the first 3 pipelines, the core infrastructe is created.

7. These steps created a managed identity for Azure Automation. To deploy Azure Automation runbooks, you must now grant this managed identity the Contributor role in your subscription. [Here is how to do this](https://github.com/jordanbean-msft/automation-ado)

8. Run pipelines 4, 5 and 6.

Now you are ready to start exploring the solution using the [sample scenarios](../docs/SampleScenarios.md).