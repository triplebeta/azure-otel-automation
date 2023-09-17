param location string
param azHostingPlanId string
param appInsightsInstrumentationKey string
param appInsightsConnectionString string
param appInsightsName string
param azStorageAccountName string
param azStorageAccountPrimaryAccessKey string
param functionAppName string
param serviceNameAppName string
param eventHub_PROD_ConnectionString string
param azLogAnalyticsWorkspaceId string
//param eventHub_STAGING_ConnectionString string

resource azFunctionApp 'Microsoft.Web/sites@2021-03-01' = {
  name: functionAppName
  kind: 'functionapp'
  location: location
  identity: { type: 'SystemAssigned' }
  properties: {
    httpsOnly: true
    serverFarmId: azHostingPlanId
    siteConfig: {
      alwaysOn: false
      linuxFxVersion: 'python|3.9'
    }
  }

  // Production slot
  resource appsettings 'config' = {
    name: 'appsettings'
    properties: union(BASE_SLOT_APPSETTINGS, functionAppStickySettings.productionSlot)
  }

  // Staging slot
  /* // No longer use staging
  resource stagingSlot 'slots' = {
    name: 'staging'
    location: location
    identity: { type: 'SystemAssigned' }
    properties: {
      enabled: true
      httpsOnly: true
    }
    resource appsettings 'config' = { name: 'appsettings', properties: union(BASE_SLOT_APPSETTINGS, functionAppStickySettings.stagingSlot) }
  }
  */

  // Define which appSettings are sticky.
  resource slotsettings 'config' = {
    name: 'slotConfigNames'
    properties: {
      appSettingNames: functionAppStickySettingsKeys
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


// Set the diagnostics settings for the event hub
resource azDiagnosticLogs 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'Log to Log Analytics}'
  scope: azFunctionApp
  properties: {
    workspaceId: azLogAnalyticsWorkspaceId
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
  }
}


var functionAppStickySettings = {
  productionSlot: {
    APP_CONFIGURATION_LABEL: 'production'
//    EVENTHUB_CONNECTION_STRING: eventHub_PROD_ConnectionString
    OTEL_SERVICE_NAME: '${serviceNameAppName} (prod)'
  }
  stagingSlot: {
    APP_CONFIGURATION_LABEL: 'staging'
//    EVENTHUB_CONNECTION_STRING: eventHub_STAGING_ConnectionString
    OTEL_SERVICE_NAME: '${serviceNameAppName} (staging)'
  }
}

var functionAppStickySettingsKeys = [for setting in items(union(functionAppStickySettings.productionSlot, functionAppStickySettings.stagingSlot)): setting.key]

/* base app settings for all accounts */
var BASE_SLOT_APPSETTINGS = {
  APPINSIGHTS_INSTRUMENTATIONKEY: appInsightsInstrumentationKey
  APPLICATIONINSIGHTS_CONNECTION_STRING: appInsightsConnectionString
  AzureWebJobsStorage: 'DefaultEndpointsProtocol=https;AccountName=${azStorageAccountName};EndpointSuffix=${environment().suffixes.storage};AccountKey=${azStorageAccountPrimaryAccessKey}'
  FUNCTIONS_EXTENSION_VERSION: '~4'
  PYTHON_ENABLE_WORKER_EXTENSIONS: '1'
  EVENTHUB_CONNECTION_STRING: eventHub_PROD_ConnectionString
  FUNCTIONS_WORKER_RUNTIME: 'python'
  WEBSITE_CONTENTSHARE: toLower(azStorageAccountName)
  WEBSITE_CONTENTAZUREFILECONNECTIONSTRING: 'DefaultEndpointsProtocol=https;AccountName=${azStorageAccountName};EndpointSuffix=${environment().suffixes.storage};AccountKey=${azStorageAccountPrimaryAccessKey}'
  AzureWebJobsFeatureFlags: 'EnableWorkerIndexing'
}

/* define outputs */
output functionPrincipalId string = azFunctionApp.identity.principalId
