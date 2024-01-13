@description('The principalId of the Function App that will be used in RBAC assignment')
param funcAppPrincipalId  string

@description('Event Hub Namespace that contains the Event Hub where RBAC role will be assigned to')
param eventHubNamespaceName string

@description('Azure Event Hub name where RBAC role will be assigned to')
param eventHubName string

@description('Role to assign to the app.')
param roleId string

@description('This is the built-in Azure Event Hub Data Receiver role. See https://learn.microsoft.com/en-gb/azure/role-based-access-control/built-in-roles#azure-service-bus-data-receiver')
resource eventHubReceiverRoleDefinition 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: subscription()
  name: roleId
}


// Creating a symbolic name for an existing resource
resource eventHubNamespace 'Microsoft.EventHub/namespaces@2021-11-01' existing = {
  name: eventHubNamespaceName
}

// Get a reference to a global Service Bus Queue where RBAC will be applied to
resource eventHub 'Microsoft.EventHub/namespaces/eventhubs@2022-10-01-preview' existing = {
  name: eventHubName
  parent: eventHubNamespace
}


// Permission will be set ONLY at the Event Hub  level. If scope property is omitted then it is set for the Event Hub Namespace and inherited to all child Event Hubs.
// Assign RBAC role 'Azure Event Hub Data Receiver' to the Event Hub
resource RBACAzureEventHubDataReceiver 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, eventHub.id, eventHubReceiverRoleDefinition.id) 
  scope: eventHub
    properties: {
    principalId: funcAppPrincipalId 
    roleDefinitionId: eventHubReceiverRoleDefinition.id
    principalType: 'ServicePrincipal'
  }
}
