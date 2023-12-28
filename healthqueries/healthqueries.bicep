// Use existing workspace
resource azLogAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2021-06-01' existing = {
  name: 'pma5poc-la'  
}

resource kqlHealthQuery1 'Microsoft.OperationalInsights/workspaces/savedSearches@2020-08-01' = {
  name: 'taskerBatchDuration'
  parent: azLogAnalyticsWorkspace
  properties: {
    category: 'Health'
    displayName: 'Tasker Batch Duration'
    functionAlias: 'BatchDuration'
    query: loadTextContent('./Tasker/BatchDuration.kql')
    tags: [{name: 'type', value: 'health' }]
  }
  etag: '*'
}

resource kqlHealthQuery2 'Microsoft.OperationalInsights/workspaces/savedSearches@2020-08-01' = {
  name: 'healthTasks-2'
  parent: azLogAnalyticsWorkspace
  properties: {
    category: 'Health'
    displayName: 'Tasker Health2'
    functionAlias: 'TaskerHealth2'
    query: loadTextContent('./Tasker/BatchHealth.kql')
    tags: [{name: 'type', value: 'health' }]
  }
  etag: '*'
}
