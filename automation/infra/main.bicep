param appName string
param region string
param environment string
param location string = resourceGroup().location

module names 'resource-names.bicep' = {
  name: 'resource-names'
  params: {
    appName: appName
    region: region
    env: environment
  }
}

module managedIdentityDeployment 'managed-identities.bicep' = {
  name: 'managed-identity-deployment'
  params: {
    managedIdentityName: names.outputs.managedIdentityName
    location: location
  }
}

module loggingDeployment 'logging.bicep' = {
  name: 'logging-deployment'
  params: {
    location: location
    logAnalyticsWorkspaceName: names.outputs.logAnalyticsWorkspaceName
  }
}

module automationAccountDeployment 'automation.bicep' = {
  name: 'automation-account-deployment'
  params: {
    automationAccountName: names.outputs.automationAccountName
    location: location
    managedIdentityName: managedIdentityDeployment.outputs.managedIdentityName
    logAnalyticsWorkspaceName: loggingDeployment.outputs.logAnalyticsWorkspaceName
  }
}
