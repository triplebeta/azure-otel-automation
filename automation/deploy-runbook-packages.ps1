param (
    [Parameter(Mandatory=$true)][String]$ResourceGroupName
)

#
# Install Python packages in the Automation Account so that the Runbooks can use it.
#

$errorActionPreference = "stop"

Import-Module Az.Resources
Import-Module Az.Automation

$automationAccountName = (Get-AzResource -ResourceGroupName $ResourceGroupName | Where-Object ResourceType -eq "Microsoft.Automation/automationAccounts").name

if(!$automationAccountName) {
  throw 'Unable to find Automation Account in $ResourceGroupName'
}

$automationAccount = Get-AzAutomationAccount -ResourceGroupName $ResourceGroupName `
                                             -Name $automationAccountName

# The following packages will be installed
Write-Information 'Installing Python packages into the Automation Account...'
New-AzAutomationPython3Package -AutomationAccountName $automationAccountName -ResourceGroupName $ResourceGroupName -Name azure-core -ContentLinkUri https://files.pythonhosted.org/packages/9c/f8/1cf23a75cb8c2755c539ac967f3a7f607887c4979d073808134803720f0f/azure_core-1.29.5-py3-none-any.whl
New-AzAutomationPython3Package -AutomationAccountName $automationAccountName -ResourceGroupName $ResourceGroupName -Name azure-identity -ContentLinkUri https://files.pythonhosted.org/packages/30/10/5dbf755b368d10a28d55b06ac1f12512a13e88874a23db82defdea9a8cd9/azure_identity-1.15.0-py3-none-any.whl
New-AzAutomationPython3Package -AutomationAccountName $automationAccountName -ResourceGroupName $ResourceGroupName -Name typing_extensions -ContentLinkUri https://files.pythonhosted.org/packages/24/21/7d397a4b7934ff4028987914ac1044d3b7d52712f30e2ac7a2ae5bc86dd0/typing_extensions-4.8.0-py3-none-any.whl
New-AzAutomationPython3Package -AutomationAccountName $automationAccountName -ResourceGroupName $ResourceGroupName -Name msal -ContentLinkUri https://files.pythonhosted.org/packages/2a/45/d80a35ce701c1b3b53ab57a585813636acba39f3a8ed87ac01e0f1dfa3c1/msal-1.25.0-py2.py3-none-any.whl

Write-Information 'All packaged installed.'