#
# Helper script to remove all the Azure Log Analytics functions.
# Sometimes that the easiest way to move on after some tinkering.
#

# Azure Login
Connect-AzAccount

$resourceGroup = "otelpoc"
$workspaceName = "otelpoc-la"

# Get all saved searches
$savedSearches = az monitor log-analytics workspace saved-search list --resource-group $resourceGroup --workspace-name $workspaceName | ConvertFrom-Json

$categoriesToRemove = @("Health", "Samples", "Sample")
foreach ($search in $savedSearches) {
    $searchName = $search.name
	if ($categoriesToRemove -contains $search.category) {
		Write-Host "Removing saved search: $searchName"
		az monitor log-analytics workspace saved-search delete --resource-group $resourceGroup --workspace-name $workspaceName --name $searchName --yes
	}
}

Write-Host "All selected saved searches were removed."