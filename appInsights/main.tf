terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = "~>2.0"
    }
  }
  backend "azurerm" {
    resource_group_name  = "pma5-poc"
    storage_account_name = "pma5pocstorage"
    container_name       = "tfstate"
    key                  = "terraform.tfstate"
  }
}

# Azurerm Provider configuration
provider "azurerm" {
  features {}
}

data "azurerm_resource_group" "parent_group" {
  name = "pma5-poc"
}

data "azurerm_application_insights" "myAi" {
  name = "pma5poc-ai"
  resource_group_name = data.azurerm_resource_group.parent_group.name
}

# Create a set of all KQL files in the directory.
locals {
  tasker_function_files = fileset(path.module, "./Tasker/Functions/*.kql")
  tasker_query_files = fileset(path.module, "./Tasker/Queries/*.kql")
}

# Create a function for each file in Functions
resource "azurerm_application_insights_analytics_item" "myAiFunc" {
  for_each = local.tasker_function_files

  application_insights_id = data.azurerm_application_insights.myAi.id
  type = "function"   # must be query, function, folder or recent
  name = "item"
  scope = "shared"
  function_alias = substr(basename(each.value),0, length(basename(each.value))-4) 
  content = file(each.value)
}

# Create a query for each file in Queries
resource "azurerm_application_insights_analytics_item" "myAiFunc" {
  for_each = local.tasker_query_files

  application_insights_id = data.azurerm_application_insights.myAi.id
  type = "query"   # must be query, function, folder or recent
  name = "item"
  scope = "shared"
  function_alias = substr(basename(each.value),0, length(basename(each.value))-4) 
  content = file(each.value)
}

