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
  name = "pma5poc-ai"
  resource_group_name = data.azurerm_resource_group.parent_group.name
}

# Create a set of all KQL files in the directory.
locals {
  events_function_files = fileset("${path.module}/modules/Events/Functions", "*.kql")
}


# ======================================
# Health functions
# ======================================

# Create a function for each file in Functions
resource "azurerm_application_insights_analytics_item" "eventsFunctions" {
  for_each = local.events_function_files

  application_insights_id = data.azurerm_application_insights.myAi.id
  type = "function"   # must be query, function, folder or recent
  name = "item"
  scope = "shared"
  function_alias = substr(basename(each.value),0, length(basename(each.value))-4) 
  content = file(each.value)
}
