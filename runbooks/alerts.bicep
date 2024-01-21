/*
  Create an AlertRuleGroup that will send and email and will start a Runbook.
  This can then be used in an Alert.

  You can depoy it using:
    az deployment group create --resource-group <resourcegroup> --template-file alerts.bicep
*/

param actionGroupName string = 'On-Call Team'
param alertRuleName string = 'NotifyOnCallTeam'
var actionGroupEmail = 'test@example.com'

resource automationAccount 'Microsoft.Automation/automationAccounts@2023-11-01' existing = {
  name: 'otelpoc-aa'
}

resource runbookForAlerts 'Microsoft.Automation/automationAccounts/runbooks@2023-11-01' existing = {
  parent: automationAccount
  name: 'Write-HelloWorld'
}

// Create a webhook for this runbook
resource runbookForAlertsWebhook 'Microsoft.Automation/automationAccounts/webhooks@2015-10-31' = {
  name: 'WebhookForAlerts'
  parent: automationAccount
  properties: {
    expiryTime: '2024-12-31 23:59:59'
    isEnabled: true
    parameters: {}
    runbook: {
      name: runbookForAlerts.name
    }
  }
}

resource supportTeamActionGroup 'Microsoft.Insights/actionGroups@2023-01-01' = {
  name: actionGroupName
  location: 'global'
  properties: {
    enabled: true
    groupShortName: 'oncallteam'
    emailReceivers: [
      {
        name: actionGroupName
        emailAddress: actionGroupEmail
        useCommonAlertSchema: true
      }
    ]
    automationRunbookReceivers: [
      {
        name: 'myRunbookReceiver'
        automationAccountId: automationAccount.id
        isGlobalRunbook: false
        runbookName: runbookForAlerts.name
        webhookResourceId: runbookForAlertsWebhook.id

        // Note: this MUST be done with a reference to make it work.
        // AND it only works in the same run that creates the webhook, otherwise the uri is empty.
        // Workaround might be to generate unique name for the webhook (but might create duplicates for older webhooks)
        serviceUri: reference('${runbookForAlertsWebhook.name}').uri
      }
    ]
  }
}


// Define what to do when an alert is fired: send en email
resource alertProcessingRule 'Microsoft.AlertsManagement/actionRules@2021-08-08' = {
  name: alertRuleName
  location: 'global'
  properties: {
    actions: [
      {
        actionType: 'AddActionGroups'
        actionGroupIds: [
          supportTeamActionGroup.id
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
