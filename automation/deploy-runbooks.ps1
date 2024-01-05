param (
    [Parameter(Mandatory=$true)][String]$ResourceGroupName
)

$errorActionPreference = "stop"

Import-Module Az.Resources
Import-Module Az.Automation

$automationAccountName = (Get-AzResource -ResourceGroupName $ResourceGroupName | Where-Object ResourceType -eq "Microsoft.Automation/automationAccounts").name

if(!$automationAccountName) {
  throw 'Unable to find Automation Account in $ResourceGroupName'
}

$automationAccount = Get-AzAutomationAccount -ResourceGroupName $ResourceGroupName `
                                             -Name $automationAccountName

Write-Information 'Starting source control sync...'
$sc = Get-AzAutomationSourceControl -ResourceGroupName $automationAccount.ResourceGroupName `
                                    -AutomationAccountName $automationAccount.AutomationAccountName

$syncJob = Start-AzAutomationSourceControlSyncJob -ResourceGroupName $automationAccount.ResourceGroupName `
                                                  -AutomationAccountName $automationAccount.AutomationAccountName `
                                                  -SourceControlName $sc.Name

$syncJobResult = Get-AzAutomationSourceControlSyncJob -ResourceGroupName $automationAccount.ResourceGroupName `
                                                      -AutomationAccountName $automationAccount.AutomationAccountName `
                                                      -SourceControlName $sc.Name `
                                                      -JobId $syncJob.SourceControlSyncJobId

while ($syncJobResult.ProvisioningState -eq 'New' -or $syncJobResult.ProvisioningState -eq 'Running') {
    $syncJobResult = Get-AzAutomationSourceControlSyncJob -ResourceGroupName $automationAccount.ResourceGroupName `
                                                          -AutomationAccountName $automationAccount.AutomationAccountName `
                                                          -SourceControlName $sc.Name `
                                                          -JobId $syncJob.SourceControlSyncJobId 
    Write-Information "Waiting for sync job to complete..."
    Start-Sleep -Seconds 3
}

$syncJobResult