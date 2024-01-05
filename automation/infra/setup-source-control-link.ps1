param (
    [Parameter(Mandatory=$true)][String]$ResourceGroupName,
    [Parameter(Mandatory=$false)][String]$SourceControlType = "VsoGit",
    [Parameter(Mandatory=$false)][String]$SourceControlBranch = "master",
    [Parameter(Mandatory=$true)][String]$adoAccountName,
    [Parameter(Mandatory=$true)][String]$RepositoryName,
    [Parameter(Mandatory=$true)][String]$PathToRunbooks,
    [Parameter(Mandatory=$true)][String]$AdoPat
)

$errorActionPreference = "stop"

Import-Module Az.Resources
Import-Module Az.Automation

$automationAccountName = (Get-AzResource -ResourceGroupName $ResourceGroupName | Where-Object ResourceType -eq "Microsoft.Automation/automationAccounts").name

if(!$automationAccountName) {
  throw 'Unable to find Automation Account in $ResourceGroupName'
}

$adoPathSecureString = ConvertTo-SecureString -String $AdoPat -AsPlainText -Force

New-AzAutomationSourceControl -Name SCReposGit `
                              -RepoUrl https://dev.azure.com/$adoAccountName/_git/$RepositoryName `
                              -SourceType $SourceControlType `
                              -AccessToken $adoPathSecureString `
                              -Branch $SourceControlBranch `
                              -ResourceGroupName $ResourceGroupName `
                              -AutomationAccountName $automationAccountName `
                              -FolderPath "/$PathToRunbooks"