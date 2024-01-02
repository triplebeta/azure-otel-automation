terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
    }
  }
}

data "azurerm_resource_group" "parent_group" {
  name = var.main_resource_group
}

data "azurerm_application_insights" "myAi" {
  name = var.app_insights_name
  resource_group_name = data.azurerm_resource_group.parent_group.name
}


# ======================================
# Health functions
# ======================================

data "azurerm_log_analytics_workspace" "myWorkspace" {
  name = var.log_analytics_workspace_name
  resource_group_name = data.azurerm_resource_group.parent_group.name
}

# Create a set of all KQL files in the directory.
locals {
  events_function_files = fileset("./modules/Events/Functions", "*.kql")
}

# Create a function under Log Analytics for each file in the Functions folder. 
resource "azurerm_log_analytics_saved_search" "laTasksFunctions" {
  for_each = local.events_function_files

  name                       = substr(basename(each.value),0, length(basename(each.value))-4)
  log_analytics_workspace_id = data.azurerm_log_analytics_workspace.myWorkspace.id
  function_alias = substr(basename(each.value),0, length(basename(each.value))-4) 

  category     = "Health"
  display_name = substr(basename(each.value),0, length(basename(each.value))-4)
  query        = file("./modules/Events/Functions/${each.value}")
}