param actionGroupName string = 'On-Call Team Triple Beta'
param alertRuleName string = 'AlertRuleName'
param location string = resourceGroup().location

var actionGroupEmail = 'jeroen@triplebeta.nl'

resource supportTeamActionGroup 'Microsoft.Insights/actionGroups@2023-01-01' = {
  name: actionGroupName
  location: location
  properties: {
    enabled: true
    groupShortName: actionGroupName
    emailReceivers: [
      {
        name: actionGroupName
        emailAddress: actionGroupEmail
        useCommonAlertSchema: true
      }
    ]
  }
}

// Get a reference to the group named above.
resource actionGroup 'Microsoft.Insights/actionGroups@2021-09-01' existing = {
  name: actionGroupName
}

// Define what to do when an alert is fired: send en email
resource alertProcessingRule 'Microsoft.AlertsManagement/actionRules@2021-08-08' = {
  name: alertRuleName
  location: location
  properties: {
    actions: [
      {
        actionType: 'AddActionGroups'
        actionGroupIds: [
          actionGroup.id
        ]
      }
    ]
    conditions: [
      {
        field: 'MonitorService'
        operator: 'Equals'
        values: [
          'Azure Backup'
        ]
      }
    ]
    enabled: true
    scopes: [
      resourceGroup().id
    ]
  }
}

// Refer to existing Log Analytics Workbench
resource logAnalyticsWorkspacePma 'Microsoft.OperationalInsights/workspaces@2022-10-01' existing = {
  name: 'pma5poc-la'
}
