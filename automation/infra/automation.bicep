param automationAccountName string
param location string
param managedIdentityName string
param logAnalyticsWorkspaceName string

resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' existing = {
  name: managedIdentityName
}

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2021-06-01' existing = {
  name: logAnalyticsWorkspaceName
}

resource automationAccount 'Microsoft.Automation/automationAccounts@2021-06-22' = {
  name: automationAccountName
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentity.id}': {}
    }
  }
  properties: {
    sku: {
      name: 'Basic'
    }
  }
  resource userAssignedManagedIdentityClientIdVariable 'variables@2019-06-01' = {
    name: 'AUTOMATION_SC_USER_ASSIGNED_IDENTITY_ID'
    properties: {
      value: '"${managedIdentity.properties.clientId}"'
    }
  }
}

var automationAccountLinkedWorkspaceName = 'Automation'

resource automationAccountLinkedWorkspace 'Microsoft.OperationalInsights/workspaces/linkedServices@2020-08-01' = {
  name: '${logAnalyticsWorkspace.name}/${automationAccountLinkedWorkspaceName}'
  properties: {
    resourceId: '${automationAccount.id}'
  }
}

resource diagnosticSettings 'Microsoft.Automation/automationAccounts/providers/diagnosticSettings@2021-05-01-preview' = {
  name: '${automationAccount.name}/Microsoft.Insights/${automationAccountLinkedWorkspaceName}'
  location: location
  properties: {
    name: automationAccountLinkedWorkspaceName
    workspaceId: logAnalyticsWorkspace.id
    logs: [
      {
        category: 'JobLogs'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: 0
        }
      }
      {
        category: 'JobStreams'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: 0
        }
      }
      {
        category: 'DscNodeStatus'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
      {
        category: 'AuditEvent'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: 0
        }
      }
    ]
  }
}
