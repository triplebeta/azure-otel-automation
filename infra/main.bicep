@description('Deployment name (used as parent ID for child deployments)')
param deploymentNameId string = '0000000000'
param location string = resourceGroup().location

var azAppConfigurationName = 'PMA5poc'
var envResourceNamePrefix = 'pma5poc'


// ========================================================
// Create storage account for function app prereq
// ========================================================

resource azStorageAccount 'Microsoft.Storage/storageAccounts@2021-08-01' = {
  name: '${envResourceNamePrefix}storage'
  location: location
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
  }
}
var azStorageAccountPrimaryAccessKey = listKeys(azStorageAccount.id, azStorageAccount.apiVersion).keys[0].value

// ========================================================
// Log Analytics & Application Insights
// ========================================================

// Create Anlytics Logs Workspaces
param logAnalyticsSkuName string = 'PerGB2018'    // Defaulting to Free tier
resource workspace 'Microsoft.OperationalInsights/workspaces@2021-06-01' = {
  name: '${envResourceNamePrefix}-la'
  location: location
  properties: {
//    retentionInDays: retentionInDays
    sku: {
      name: logAnalyticsSkuName
    }
  }
}

// create application insights resource
resource azAppInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: '${envResourceNamePrefix}-ai'
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
    // by referencing outputs of workspaces deployment
    // we ensure that it get created before this resource.
    WorkspaceResourceId: workspace.id
  }
  tags: {
    // Needed for in the portal, according to https://markheath.net/post/azure-functions-bicep
    // circular dependency means we can't reference functionApp directly  /subscriptions/<subscriptionId>/resourceGroups/<rg-name>/providers/Microsoft.Web/sites/<appName>"
     'hidden-link:/subscriptions/${subscription().id}/resourceGroups/${resourceGroup().name}/providers/Microsoft.Web/sites/${functionAppEventsGBRName}': 'Resource'
     'hidden-link:/subscriptions/${subscription().id}/resourceGroups/${resourceGroup().name}/providers/Microsoft.Web/sites/${functionAppTasksName}': 'Resource'
  }
}
var azAppInsightsInstrumentationKey = azAppInsights.properties.InstrumentationKey
var azAppInsightsConnectionString = azAppInsights.properties.ConnectionString

// ========================================================
// AppServicePlan
// ========================================================

resource azHostingPlan 'Microsoft.Web/serverfarms@2021-03-01' = {
  name: '${envResourceNamePrefix}-asp'
  location: location
  kind: 'linux'
  sku: {
    name: 'Y1'  // el cheapo
  }
  properties: {
    reserved: true
  }
}


// ========================================================
// Function Apps & slots
// ========================================================

// Must be defined separately since they are also used in the hidden tag of the AppInsights to avoid circular references.
var functionAppEventsGBRName = '${envResourceNamePrefix}-eventsgbr-app'
var functionAppTasksName = '${envResourceNamePrefix}-tasks-app'


// set the app settings on function app's deployment slots
module azFunctionAppEventsGBR 'functionApp.bicep' = {
  name: '${deploymentNameId}-eventsgbr'
  params: {
    functionAppName: functionAppEventsGBRName
    location: location
    azHostingPlanId: azHostingPlan.id
    deploymentNameId: '${deploymentNameId}-events'
    appInsightsInstrumentationKey: azAppInsightsInstrumentationKey
    appInsightsConnectionString: azAppInsightsConnectionString
    appInsightsName: azAppInsights.name
    azAppConfigurationName: azAppConfigurationName
    azStorageAccountName: azStorageAccount.name
    azStorageAccountPrimaryAccessKey: azStorageAccountPrimaryAccessKey
    eventHubConnectionString: 'EntityPath=eventsgbr;${azEventHubConnectionString}'
  }
}


// set the app settings on function app's deployment slots
module azFunctionAppTasks 'functionApp.bicep' = {
  name: '${deploymentNameId}-tasks'
  params: {
    functionAppName: functionAppTasksName
    location: location
    azHostingPlanId: azHostingPlan.id
    deploymentNameId: '${deploymentNameId}-tasks'
    appInsightsInstrumentationKey: azAppInsightsInstrumentationKey
    appInsightsConnectionString: azAppInsightsConnectionString
    appInsightsName: azAppInsights.name
    azAppConfigurationName: azAppConfigurationName
    azStorageAccountName: azStorageAccount.name
    azStorageAccountPrimaryAccessKey: azStorageAccountPrimaryAccessKey
    eventHubConnectionString: 'EntityPath=tasks;${azEventHubConnectionString}'
  }
}


// ========================================================
// Event Hub
// ========================================================

var eventHubSku = 'Basic'

resource azEventHubNamespace 'Microsoft.EventHub/namespaces@2021-11-01' = {
  name: '${envResourceNamePrefix}eventhub-ns'
  location: location
  sku: {
    name: eventHubSku
    tier: eventHubSku
    capacity: 1
  }
  properties: {
    isAutoInflateEnabled: false
    maximumThroughputUnits: 0
  }
}


resource azEventHubEventsGBR 'Microsoft.EventHub/namespaces/eventhubs@2021-11-01' = {
  parent: azEventHubNamespace
  name: 'eventsgbr'
  properties: {
    messageRetentionInDays: 1
    partitionCount: 1
  }
}

// Assign the EventsGBR functionApp the Event Hub Data Sender role
var azureEventHubDataSenderRoleId = '2b629674-e913-4c01-ae53-ef4638d8f975' // Azure Event Hub Data Sender

// set the app settings on function app's deployment slots
module azAssignEventHubDataSenderRole 'eventHub-roleassignment.bicep' = {
  name: '${deploymentNameId}-EventsGBRDataSenderRole'
  params: {
    eventHubName: azEventHubEventsGBR.name
    eventHubNamespaceName: azEventHubNamespace.name
    roleId: azureEventHubDataReceiverRoleId
    funcAppPrincipalId: azFunctionAppTasks.outputs.functionPrincipalId
  }
}

// Assign the Tasks functionApp the Event Hub Data Receiver role
var azureEventHubDataReceiverRoleId = 'a638d3c7-ab3a-418d-83e6-5f17a39d4fde' // Azure Event Hub Data Receiver

// set the app settings on function app's deployment slots
module azAssignEventHubDataReceiverRole 'eventHub-roleassignment.bicep' = {
  name: '${deploymentNameId}-TasksDataReceiverRole'
  params: {
    eventHubName: azEventHubEventsGBR.name
    eventHubNamespaceName: azEventHubNamespace.name
    roleId: azureEventHubDataSenderRoleId
    funcAppPrincipalId: azFunctionAppEventsGBR.outputs.functionPrincipalId
  }
}

// Create event hub authorizationRules
resource azTestEventHub_Producer 'Microsoft.EventHub/namespaces/eventhubs/authorizationRules@2022-01-01-preview' = {
  parent: azEventHubEventsGBR
  name: 'Producer'
  properties: {
    rights: [
      'Send'
    ]
  }
}
var azEventHubConnectionString = listKeys(azTestEventHub_Producer.id, azTestEventHub_Producer.apiVersion).primaryConnectionString

output eventsGBRFunctionPrincipalId string = azAppConfigurationName
output tasksFunctionPrincipalId string = azAppConfigurationName



/* define outputs */
output appConfigName string = azAppConfigurationName
output appInsightsInstrumentionKey string = azAppInsightsInstrumentationKey
