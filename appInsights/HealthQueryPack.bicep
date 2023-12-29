//param deploymentId string = newGuid()

resource healthQueryPack 'Microsoft.OperationalInsights/queryPacks@2019-09-01' = {
  name: 'MyHealthQueryPack'
  location: resourceGroup().location
  properties: {}
}

resource healthQuery1 'Microsoft.OperationalInsights/queryPacks/queries@2019-09-01' = {
  name: 'b402c7ed-0c50-4c07-91c4-e975694fdd30'
  parent: healthQueryPack
  properties: {
    body: loadTextContent('./Tasker/BatchDuration.kql')
    description: 'How much time did the batch take.'
    displayName: 'Tasker Batch Duration'
    properties: {}
    related: {
      categories: [
        'applications'
      ]
      resourceTypes: [
        'microsoft.insights/components'
        'microsoft.operationalinsights/workspaces'
      ]
      solutions: [
        'ApplicationInsights'
      ]
    }
    tags: {}
  }
}
