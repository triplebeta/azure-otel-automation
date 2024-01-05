param appName string
param location string = resourceGroup().location

module managedIdentityDeployment 'managed-identities.bicep' = {
  name: 'managed-identity-deployment'
  params: {
    managedIdentityName: '${appName}-automation-mi'
    location: location
  }
}


module automationAccountDeployment 'automation.bicep' = {
  name: 'automation-account-deployment'
  params: {
    automationAccountName: '${appName}-aa'
    location: location
    managedIdentityName: managedIdentityDeployment.outputs.managedIdentityName
    logAnalyticsWorkspaceName: '${appName}-la'
  }
}
