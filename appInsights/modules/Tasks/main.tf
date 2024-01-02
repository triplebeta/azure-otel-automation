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
# Query pack(s)
# ======================================

# Create a set of all KQL files in the directory.
locals {
  tasks_querypack = fileset(path.module, "./modules/Tasks/TasksQueryPack/*.kql")
}

resource "azurerm_log_analytics_query_pack" "tasksQueryPack" {
  name                = "TasksQueryPack"
  resource_group_name = data.azurerm_resource_group.parent_group.name
  location            = data.azurerm_resource_group.parent_group.location
}

resource "azurerm_log_analytics_query_pack_query" "BatchDurationQuery" {
  name = "d26b7a8c-c723-441e-965b-fd591ce07649"
  query_pack_id = azurerm_log_analytics_query_pack.tasksQueryPack.id

  description = "How much time did the batch take."
  display_name = "Tasks Batch Duration"
  body = file("${path.module}/TasksQueryPack/BatchDuration.kql")
  categories = [ "applications" ]
  resource_types = [
      "microsoft.insights/components",
      "microsoft.operationalinsights/workspaces"
    ]
  solutions = [
      "ApplicationInsights"
    ]
  tags = {}
}

# ======================================
# Health functions
# ======================================

# Create a set of all KQL files in the directory.
locals {
  tasks_function_files = fileset("./modules/Tasks/Functions", "*.kql")
  TaskBatchFailedHealth = "./modules/Tasks/Functions/TaskBatchFailedHealth.kql"
}

# Create a function for each file in Functions
resource "azurerm_application_insights_analytics_item" "tasksFunctions" {
  for_each = local.tasks_function_files

  application_insights_id = data.azurerm_application_insights.myAi.id
  type = "function"   # must be query, function, folder or recent
  name = "item"
  scope = "shared"
  function_alias = substr(basename(each.value),0, length(basename(each.value))-4) 
  content = file("./modules/Tasks/Functions/${each.value}")
}


# ======================================
# Azure portal dashboard
# ======================================

data "azurerm_subscription" "current" {}

resource "azurerm_portal_dashboard" "machine-dashboard" {
  name                = "machine-dashboard"
  resource_group_name = data.azurerm_resource_group.parent_group.name
  location            = data.azurerm_resource_group.parent_group.location
  tags = {
    hidden-title = "PMA5 Machine Dashboard"
  }

  // In the tpl file you can use these like: ${dashboard_title}
  dashboard_properties =  templatefile("${path.module}/Dashboards/MachineDashboard.tpl",
    {
      dashboard_title = "PMA5 Machine Dashboard",
      sub_id     = data.azurerm_subscription.current.subscription_id
      })
}
