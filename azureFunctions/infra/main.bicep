@description('Deployment name (used as parent ID for child deployments)')
param deploymentNameId string = '0000000000'
param location string = resourceGroup().location

var envResourceNamePrefix = 'otelpoc'


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
  
  resource tfBlobService 'blobServices@2023-01-01' = {
    name: 'default'
  }
}

// Create a Key Vault to store the credentials for the webhooks
// of the Runbooks, so we can invoke them from an alert.
resource azKeyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: '${envResourceNamePrefix}-kv'
  location: location
  properties: {
    tenantId: tenant().tenantId
    sku: {
      family: 'A'
      name: 'standard'
    }
    enableRbacAuthorization: true
  }
}

// Create container for Terraform state of runbooks
resource container_tf_runbooks 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = {
  name: '${envResourceNamePrefix}storage/default/tfstate-runbooks'
  properties: {
    publicAccess: 'None'
  }
  dependsOn: [
    azStorageAccount
  ]
}

// Create container for Terraform state of runbooks
resource container_tf_appinsights 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = {
  name: '${envResourceNamePrefix}storage/default/tfstate-appinsights'
  properties: {
    publicAccess: 'None'
  }
  dependsOn: [
    azStorageAccount
  ]
}

// TODO Find a better way than using listKeys
#disable-next-line use-resource-symbol-reference
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
     'hidden-link:/subscriptions/${subscription().id}/resourceGroups/${resourceGroup().name}/providers/Microsoft.Web/sites/${functionAppEventsName}': 'Resource'
     'hidden-link:/subscriptions/${subscription().id}/resourceGroups/${resourceGroup().name}/providers/Microsoft.Web/sites/${functionAppTasksName}': 'Resource'
  }
}
var azAppInsightsInstrumentationKey = azAppInsights.properties.InstrumentationKey
var azAppInsightsConnectionString = azAppInsights.properties.ConnectionString


// ========================================================
// Azure Automation account
// ========================================================

// Azure Account for Runbooks for the Standard Operating Procedures.
resource sop_aa 'Microsoft.Automation/automationAccounts@2023-11-01' = {
  name: 'standard-operating-proc-aa'
  location: location
  properties: {
    sku: {
      name: 'Basic'
    }
  }
  identity: {
    type: 'SystemAssigned'
  }
}

/*
// Assigning Contibutor role still fails.
// But it's not yet clear why it would need that role.

// Grant Contributor role to system assigned identity
resource AutomationAccountContributorRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, sop_aa.id) 
  scope: resourceGroup()
    properties: {
    principalId: sop_aa.identity.principalId
    
    // See: https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles
    roleDefinitionId: 'b24988ac-6180-42a0-ab88-20f7382dd24c' // Contributor
    principalType: 'ServicePrincipal'
  }
}
*/

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
// Function Apps
// ========================================================

// Must be defined separately since they are also used in the hidden tag of the AppInsights to avoid circular references.
var functionAppEventsName = '${envResourceNamePrefix}-events-app'
var functionAppTasksName = '${envResourceNamePrefix}-tasks-app'


// set the app settings on function app's deployment slots
module azFunctionAppEvents 'functionApp.bicep' = {
  name: '${deploymentNameId}-events'
  params: {
    serviceNameAppName: 'Events'
    functionAppName: functionAppEventsName
    location: location
    azHostingPlanId: azHostingPlan.id
    appInsightsInstrumentationKey: azAppInsightsInstrumentationKey
    appInsightsConnectionString: azAppInsightsConnectionString
    appInsightsName: azAppInsights.name
    azStorageAccountName: azStorageAccount.name
    azStorageAccountPrimaryAccessKey: azStorageAccountPrimaryAccessKey
    eventHub_PROD_ConnectionString: azEventHubEvents_Sender_ConnectionString
    azLogAnalyticsWorkspaceId: azLogAnalyticsWorkspace.id
  }
}


// set the app settings on function app's deployment slots
module azFunctionAppTasks 'functionApp.bicep' = {
  name: '${deploymentNameId}-tasks'
  params: {
    serviceNameAppName: 'Tasks'
    functionAppName: functionAppTasksName
    location: location
    azHostingPlanId: azHostingPlan.id
    appInsightsInstrumentationKey: azAppInsightsInstrumentationKey
    appInsightsConnectionString: azAppInsightsConnectionString
    appInsightsName: azAppInsights.name
    azStorageAccountName: azStorageAccount.name
    azStorageAccountPrimaryAccessKey: azStorageAccountPrimaryAccessKey
    eventHub_PROD_ConnectionString: azEventHubEvents_Listener_ConnectionString
    azLogAnalyticsWorkspaceId: azLogAnalyticsWorkspace.id
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

resource azEventHubEvents 'Microsoft.EventHub/namespaces/eventhubs@2021-11-01' = {
  parent: azEventHubNamespace
  name: 'events'
  properties: {
    messageRetentionInDays: 1
    partitionCount: 1
  }
}

// Create event hub authorizationRule for the Sender and the Listener
resource azEventHubEvents_Sender 'Microsoft.EventHub/namespaces/eventhubs/authorizationRules@2022-01-01-preview' = {
  parent: azEventHubEvents
  name: 'Producer'
  properties: {
    rights: [
      'Send'
    ]
  }
}
resource azEventHubEvents_Listener 'Microsoft.EventHub/namespaces/eventhubs/authorizationRules@2022-01-01-preview' = {
  parent: azEventHubEvents
  name: 'Consumer'
  properties: {
    rights: [
      'Listen'
    ]
  }
}

#disable-next-line use-resource-symbol-reference // TODO Find a better way than using listKeys
var azEventHubEvents_Sender_ConnectionString = listKeys(azEventHubEvents_Sender.id, azEventHubEvents_Sender.apiVersion).primaryConnectionString

#disable-next-line use-resource-symbol-reference // TODO Find a better way than using listKeys
var azEventHubEvents_Listener_ConnectionString = listKeys(azEventHubEvents_Listener.id, azEventHubEvents_Listener.apiVersion).primaryConnectionString


// =================================================================================
// Assign the Sender and Listener roles to the Service Principals of the functions
// =================================================================================

// Assign the SP of the Events functionApp the Event Hub Data Sender role
module azAssignEventHubDataSenderRole 'eventHub-roleassignment.bicep' = {
  name: '${deploymentNameId}-EventsDataSenderRole'
  params: {
    eventHubName: azEventHubEvents.name
    eventHubNamespaceName: azEventHubNamespace.name
    roleId: azureEventHubDataSenderRoleId
    funcAppPrincipalId: azFunctionAppEvents.outputs.functionPrincipalId
  }
}

// Assign the SP of the Tasks functionApp the Event Hub Data Receiver role
module azAssignEventHubDataReceiverRole 'eventHub-roleassignment.bicep' = {
  name: '${deploymentNameId}-TasksDataReceiverRole'
  params: {
    eventHubName: azEventHubEvents.name
    eventHubNamespaceName: azEventHubNamespace.name
    roleId: azureEventHubDataReceiverRoleId
    funcAppPrincipalId: azFunctionAppTasks.outputs.functionPrincipalId
  }
}


/* Service Principals for the function apps */
output eventsFunctionPrincipalId string = azFunctionAppEvents.outputs.functionPrincipalId
output tasksFunctionPrincipalId string = azFunctionAppTasks.outputs.functionPrincipalId


/* define outputs */
output appInsightsInstrumentionKey string = azAppInsightsInstrumentationKey
