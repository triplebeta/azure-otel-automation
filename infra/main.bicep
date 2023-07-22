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
}
var azAppInsightsInstrumentationKey = azAppInsights.properties.InstrumentationKey


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

// set the app settings on function app's deployment slots
module functionAppEventsGBR 'functionApp.bicep' = {
  name: '${deploymentNameId}-eventsgbr'
  params: {
    functionAppName: '${envResourceNamePrefix}-eventsgbr-app'
    location: location
    azHostingPlanId: azHostingPlan.id
    deploymentNameId: '${deploymentNameId}-events'
    azAppInsightsInstrumentationKey: azAppInsightsInstrumentationKey
    azAppConfigurationName: azAppConfigurationName
    azStorageAccountName: azStorageAccount.name
    azStorageAccountPrimaryAccessKey: azStorageAccountPrimaryAccessKey
  }
}


// set the app settings on function app's deployment slots
module functionAppTasks 'functionApp.bicep' = {
  name: '${deploymentNameId}-tasks'
  params: {
    functionAppName: '${envResourceNamePrefix}-tasks-app'
    location: location
    azHostingPlanId: azHostingPlan.id
    deploymentNameId: '${deploymentNameId}-tasks'
    azAppInsightsInstrumentationKey: azAppInsightsInstrumentationKey
    azAppConfigurationName: azAppConfigurationName
    azStorageAccountName: azStorageAccount.name
    azStorageAccountPrimaryAccessKey: azStorageAccountPrimaryAccessKey
  }
}


// ========================================================
// Event Hub
// ========================================================

var eventHubSku = 'Basic'

resource eventHubNamespace 'Microsoft.EventHub/namespaces@2021-11-01' = {
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

resource eventHubEventsGBR 'Microsoft.EventHub/namespaces/eventhubs@2021-11-01' = {
  parent: eventHubNamespace
  name: 'eventsgbr'
  properties: {
    messageRetentionInDays: 1
    partitionCount: 1
  }
}

resource eventHubTasks 'Microsoft.EventHub/namespaces/eventhubs@2021-11-01' = {
  parent: eventHubNamespace
  name: 'tasks'
  properties: {
    messageRetentionInDays: 1
    partitionCount: 1
  }
}

resource eventHubStates 'Microsoft.EventHub/namespaces/eventhubs@2021-11-01' = {
  parent: eventHubNamespace
  name: 'states'
  properties: {
    messageRetentionInDays: 1
    partitionCount: 1
  }
}

/* define outputs */
output appConfigName string = azAppConfigurationName
output appInsightsInstrumentionKey string = azAppInsightsInstrumentationKey
