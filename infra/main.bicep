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
resource azLogAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2021-06-01' = {
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
    WorkspaceResourceId: azLogAnalyticsWorkspace.id
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
    serviceNameAppName: 'GBR Events'
    functionAppName: functionAppEventsGBRName
    location: location
    azHostingPlanId: azHostingPlan.id
    appInsightsInstrumentationKey: azAppInsightsInstrumentationKey
    appInsightsConnectionString: azAppInsightsConnectionString
    appInsightsName: azAppInsights.name
    azStorageAccountName: azStorageAccount.name
    azStorageAccountPrimaryAccessKey: azStorageAccountPrimaryAccessKey
    eventHub_PROD_ConnectionString: azEventHubEventsGBR_Sender_ConnectionString
    azLogAnalyticsWorkspaceId: azLogAnalyticsWorkspace.id
//    eventHub_STAGING_ConnectionString: azEventHubEventsGBRStaging_Sender_ConnectionString  // No Longer use staging
  }
}


// set the app settings on function app's deployment slots
module azFunctionAppTasks 'functionApp.bicep' = {
  name: '${deploymentNameId}-tasks'
  params: {
    serviceNameAppName: 'Tasker'
    functionAppName: functionAppTasksName
    location: location
    azHostingPlanId: azHostingPlan.id
    appInsightsInstrumentationKey: azAppInsightsInstrumentationKey
    appInsightsConnectionString: azAppInsightsConnectionString
    appInsightsName: azAppInsights.name
    azStorageAccountName: azStorageAccount.name
    azStorageAccountPrimaryAccessKey: azStorageAccountPrimaryAccessKey
    eventHub_PROD_ConnectionString: azEventHubEventsGBR_Listener_ConnectionString
    azLogAnalyticsWorkspaceId: azLogAnalyticsWorkspace.id
//    eventHub_STAGING_ConnectionString: azEventHubEventsGBRStaging_Listener_ConnectionString  // No Longer use staging
  }
}


// ========================================================
// Event Hub Namespace
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

// Set the diagnostics settings for the event hub
resource azDiagnosticLogs 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'Log to ${azEventHubNamespace.name}'
  scope: azEventHubNamespace
  properties: {
    workspaceId: azLogAnalyticsWorkspace.id
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
        retentionPolicy: {
          days: 0
          enabled: false
        }
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
        retentionPolicy: {
          days: 0
          enabled: false
        }
      }
    ]
  }
}


// ========================================================
// Create the Event Hub for production: eventgbr
// ========================================================

// Define the well-known GUIDs for the roles.
var azureEventHubDataSenderRoleId = '2b629674-e913-4c01-ae53-ef4638d8f975'   // Azure Event Hub Data Sender
var azureEventHubDataReceiverRoleId = 'a638d3c7-ab3a-418d-83e6-5f17a39d4fde' // Azure Event Hub Data Receiver

resource azEventHubEventsGBR 'Microsoft.EventHub/namespaces/eventhubs@2021-11-01' = {
  parent: azEventHubNamespace
  name: 'eventsgbr'
  properties: {
    messageRetentionInDays: 1
    partitionCount: 1
  }
}

// Create event hub authorizationRule for the Sender and the Listener
resource azEventHubEventsGBR_Sender 'Microsoft.EventHub/namespaces/eventhubs/authorizationRules@2022-01-01-preview' = {
  parent: azEventHubEventsGBR
  name: 'Producer'
  properties: {
    rights: [
      'Send'
    ]
  }
}
resource azEventHubEventsGBR_Listener 'Microsoft.EventHub/namespaces/eventhubs/authorizationRules@2022-01-01-preview' = {
  parent: azEventHubEventsGBR
  name: 'Consumer'
  properties: {
    rights: [
      'Listen'
    ]
  }
}
var azEventHubEventsGBR_Sender_ConnectionString = listKeys(azEventHubEventsGBR_Sender.id, azEventHubEventsGBR_Sender.apiVersion).primaryConnectionString
var azEventHubEventsGBR_Listener_ConnectionString = listKeys(azEventHubEventsGBR_Listener.id, azEventHubEventsGBR_Listener.apiVersion).primaryConnectionString


// ========================================================
// Create the Event Hub for STAGING: eventgbr-staging
// ========================================================
// No longer use a staging environment
/*
resource azEventHubEventsGBRStaging 'Microsoft.EventHub/namespaces/eventhubs@2021-11-01' = {
  parent: azEventHubNamespace
  name: 'eventsgbr-staging'
  properties: {
    messageRetentionInDays: 1
    partitionCount: 1
  }
}


// Create event hub authorizationRule for the Sender and the Listener
resource azEventHubEventsGBRStaging_Sender 'Microsoft.EventHub/namespaces/eventhubs/authorizationRules@2022-01-01-preview' = {
  parent: azEventHubEventsGBRStaging
  name: 'Producer'
  properties: {
    rights: [
      'Send'
    ]
  }
}
resource azEventHubEventsGBRStaging_Listener 'Microsoft.EventHub/namespaces/eventhubs/authorizationRules@2022-01-01-preview' = {
  parent: azEventHubEventsGBRStaging
  name: 'Consumer'
  properties: {
    rights: [
      'Listen'
    ]
  }
}
var azEventHubEventsGBRStaging_Sender_ConnectionString = listKeys(azEventHubEventsGBRStaging_Sender.id, azEventHubEventsGBRStaging_Sender.apiVersion).primaryConnectionString
var azEventHubEventsGBRStaging_Listener_ConnectionString = listKeys(azEventHubEventsGBRStaging_Listener.id, azEventHubEventsGBRStaging_Listener.apiVersion).primaryConnectionString
*/

// =================================================================================
// Assign the Sender and Listener roles to the Service Principals of the functions
// =================================================================================

// Assign the SP of the EventsGBR functionApp the Event Hub Data Sender role
module azAssignEventHubDataSenderRole 'eventHub-roleassignment.bicep' = {
  name: '${deploymentNameId}-EventsGBRDataSenderRole'
  params: {
    eventHubName: azEventHubEventsGBR.name
    eventHubNamespaceName: azEventHubNamespace.name
    roleId: azureEventHubDataSenderRoleId
    funcAppPrincipalId: azFunctionAppEventsGBR.outputs.functionPrincipalId
  }
}

// Assign the SP of the Tasks functionApp the Event Hub Data Receiver role
module azAssignEventHubDataReceiverRole 'eventHub-roleassignment.bicep' = {
  name: '${deploymentNameId}-TasksDataReceiverRole'
  params: {
    eventHubName: azEventHubEventsGBR.name
    eventHubNamespaceName: azEventHubNamespace.name
    roleId: azureEventHubDataReceiverRoleId
    funcAppPrincipalId: azFunctionAppTasks.outputs.functionPrincipalId
  }
}



output eventsGBRFunctionPrincipalId string = azAppConfigurationName
output tasksFunctionPrincipalId string = azAppConfigurationName



/* define outputs */
output appConfigName string = azAppConfigurationName
output appInsightsInstrumentionKey string = azAppInsightsInstrumentationKey
