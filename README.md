# Introduction
This solution shows how you can utilize standard Azure services to monitor a solution perform common maintenance actions. It implements a working solution and deployment is automated as well.

The goal of this setup is to demonstrate the capabilities and to provide a playground to tinker with it. It can help to learn how to use these concepts. Here you can find a [description of the components](Components.md).

Credits: The Azure Automation part is based on this setup: [https://github.com/jordanbean-msft/automation-ado](https://github.com/jordanbean-msft/automation-ado)


## Disclaimer
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

## Prerequisites
You should install a few plugins to be able to run the code on your local laptop:
* Python 3.11 - install from the software catalog
* [Python plugin for VS Code](https://marketplace.visualstudio.com/items?itemName=ms-python.python)
* [Azurite plugin for VS Code](https://marketplace.visualstudio.com/items?itemName=Azurite.azurite) - simulator for Azure infrastructure
* [Bicep](https://marketplace.visualstudio.com/items?itemName=ms-azuretools.vscode-bicep)- language support for the Bicep infrastructure code
* [Azure tools](https://marketplace.visualstudio.com/items?itemName=ms-vscode.vscode-node-azure-pack) - standard Microsoft plugin to work with Azure services (like functions)
* [Azure Functions](https://marketplace.visualstudio.com/items?itemName=ms-azuretools.vscode-azurefunctions) - Microsoft plugin to work with Functions
* [Azure Automation](https://marketplace.visualstudio.com/items?itemName=azure-automation.vscode-azureautomation)

## Deployment
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
* [azure-functions-infra-pipeline.yml](azureFunctions/infra/azure-functions-infra-pipeline.yml)
* [appInsights-infra-pipeline.yml](appInsights/appInsights-infra-pipeline.yml)
* [azure-automation-infra-pipeline.yml](automation/infra/azure-automation-infra-pipeline.yml)
* [deploy-events-function-pipeline.yml](azureFunctions/EventsFunction/deploy-events-function-pipeline.yml)
* [deploy-tasks-function-pipeline.yml](azureFunctions/TasksFunction/deploy-tasks-function-pipeline.yml)

* [deploy-runbooks-pipeline.yml](automation/runbooks/deploy-runbooks-pipeline.yml)

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

Now you are ready to start exploring the solution so as a next step go to [Getting started](GettingStarted.md)