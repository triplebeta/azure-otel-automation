terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = "~>2.0"
    }
  }
}

# Azurerm Provider configuration
provider "azurerm" {
  features {}
}

locals {
  kql_files = fileset(path.module, "./Tasker/*.kql")
}

resource "azurerm_resource_group" "parent_group" {
  name = "pma5-poc"
  location = "westeurope"
}

resource "azurerm_application_insights" "myAi" {
  name = "pma5poc-ai"
  location = "westeurope"
  application_type = "web"
  resource_group_name = azurerm_resource_group.parent_group.name
  lifecycle {
    ignore_changes = [
      tags,
      sampling_percentage,
      workspace_id,
      timeouts
    ]
  }
}

# Create a function for each file
resource "azurerm_application_insights_analytics_item" "myAiFunc" {
  for_each = local.kql_files

  application_insights_id = azurerm_application_insights.myAi.id
  type = "function"   # must be query, function, folder or recent
  name = "item"
  scope = "shared"
  function_alias = substr(basename(each.value),0, length(basename(each.value))-4) 
  content = file(each.value)
}

# resource "azurerm_application_insights_analytics_item" "myAiFunc1" {
#   application_insights_id = azurerm_application_insights.myAi.id
#   type = "function"   # must be query, function, folder or recent
#   name = "item"
#   scope = "shared"
#   function_alias = "BatchDuration"
#   content = file("./Tasker/BatchDuration.kql")
# }

# resource "azurerm_application_insights_analytics_item" "myAiFunc2" {
#   application_insights_id = azurerm_application_insights.myAi.id
#   type = "function"   # must be query, function, folder or recent
#   name = "item"
#   scope = "shared"
#   function_alias = "BatchHealth"
#   content = file("./Tasker/BatchHealth.kql")
# }

# resource "azurerm_application_insights_analytics_item" "myAiFunc3" {
#   application_insights_id = azurerm_application_insights.myAi.id
#   type = "function"   # must be query, function, folder or recent
#   name = "item"
#   scope = "shared"
#   function_alias = "RunsHealth"
#   content = file("./Tasker/RunsHealth.kql")
# }

