param location string
param azHostingPlanId string
param deploymentNameId string
param appInsightsInstrumentationKey string
param appInsightsConnectionString string
param appInsightsName string
param azAppConfigurationName string
param azStorageAccountName string
param azStorageAccountPrimaryAccessKey string
param functionAppName string
param eventHubConnectionString string

@description('Name of the staging deployment slot')
var functionAppStagingSlot = 'staging'


resource azFunctionApp 'Microsoft.Web/sites@2021-03-01' = {
  name: functionAppName
  kind: 'functionapp'
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    httpsOnly: true
    serverFarmId: azHostingPlanId
    // clientAffinityEnabled: true
    // reserved: false
    siteConfig: {
      alwaysOn: false
      linuxFxVersion: 'python|3.9'
    }
  }
  tags: {
    // Needed for in the portal, according to https://markheath.net/post/azure-functions-bicep
    // circular dependency means we can't reference functionApp directly  /subscriptions/<subscriptionId>/resourceGroups/<rg-name>/providers/Microsoft.Web/sites/<appName>"
    'hidden-link: /app-insights-resource-id': '/subscriptions/${subscription().id}/resourceGroups/${resourceGroup().name}/providers/microsoft.insights/components/${appInsightsName}'
    'hidden-link: /app-insights-instrumentation-key': appInsightsInstrumentationKey
    'hidden-link: /app-insights-conn-string': appInsightsConnectionString
  }
}


/* ###################################################################### */
// Create Function App's staging slot for
//   - NOTE: set app settings later
/* ###################################################################### */
resource azFunctionSlotStaging 'Microsoft.Web/sites/slots@2021-03-01' = {
  name: '${azFunctionApp.name}/${functionAppStagingSlot}'
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    enabled: true
    httpsOnly: true
  }
}

/* ###################################################################### */
// Configure & set app settings on function app's deployment slots
/* ###################################################################### */
// set specific app settings to be a slot specific values
resource functionSlotConfig 'Microsoft.Web/sites/config@2021-03-01' = {
  name: 'slotConfigNames'
  parent: azFunctionApp
  properties: {
    appSettingNames: [
      'APP_CONFIGURATION_LABEL'
    ]
  }
}


// set the app settings on function app's deployment slots
module appService_appSettings 'appservice-appsettings-config.bicep' = {
  name: '${deploymentNameId}-appservice-config'
  params: {
    
    appConfigurationName: azAppConfigurationName
    appConfiguration_appConfigLabel_value_production: 'production'
//    appConfiguration_appConfigLabel_value_staging: 'staging'
    applicationInsightsInstrumentationKey: appInsightsInstrumentationKey
    storageAccountName: azStorageAccountName
    storageAccountAccessKey: azStorageAccountPrimaryAccessKey
    functionAppName: azFunctionApp.name
    eventHubConnectionString: eventHubConnectionString
//    functionAppStagingSlotName: azFunctionSlotStaging.name
  }
}


/* define outputs */
output functionPrincipalId string = azFunctionApp.identity.principalId
