
@description('Specifies the Azure location for all resources.')
param location string = resourceGroup().location

var eventHubSku = 'Basic'
var eventHubNamespaceName = 'pma5-poc-hub-new'

resource eventHubNamespace 'Microsoft.EventHub/namespaces@2021-11-01' = {
  name: eventHubNamespaceName
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
