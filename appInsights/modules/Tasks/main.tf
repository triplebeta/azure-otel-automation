terraform {
  required_providers {
    azapi = {
      source = "azure/azapi"
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

# ======================================
# Query pack(s)
# ======================================

# Create a set of all KQL files in the directory.
locals {
  tasks_querypack = fileset(path.module, "./modules/Tasks/TasksQueryPack/*.kql")
}

resource "azapi_resource" "tasksQueryPack" {
  type = "Microsoft.OperationalInsights/queryPacks@2019-09-01"
  name = "TasksQueryPack"
  location = "westeurope"
  body = jsonencode({
    properties = {}
  })
}

resource "azapi_resource" "BatchDurationQuery" {
  type = "Microsoft.OperationalInsights/queryPacks/queries@2019-09-01"
  name = "BatchDurationQuery"
  parent_id = azapi_resource.tasksQueryPack.id
  body = jsonencode({
    properties = {
      description: "How much time did the batch take."
      displayName: "Tasker Batch Duration"
      properties: {}
      body: file("${path.module}/TasksQueryPack/BatchDuration.kql")
      related: {
        categories: [
          "applications"
        ]
        resourceTypes: [
          "microsoft.insights/components",
          "microsoft.operationalinsights/workspaces"
        ]
        solutions: [
          "ApplicationInsights"
        ]
      }
      tags: {}
    }
  })
  depends_on = [ azapi_resource.tasksQueryPack ]
}

# ======================================
# Health functions
# ======================================

# Create a set of all KQL files in the directory.
locals {
  tasks_function_files = fileset(path.module, "./modules/Tasks/Functions/*.kql")
  tasks_query_files = fileset(path.module, "./modules/Tasks/TasksQueryPack/*.kql")
}

# Create a function for each file in Functions
resource "azurerm_application_insights_analytics_item" "tasksFunctions" {
  for_each = local.tasks_function_files

  application_insights_id = data.azurerm_application_insights.myAi.id
  type = "function"   # must be query, function, folder or recent
  name = "item"
  scope = "shared"
  function_alias = substr(basename(each.value),0, length(basename(each.value))-4) 
  content = file(each.value)
}

