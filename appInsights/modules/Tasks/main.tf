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

# ======================================
# Query pack(s)
# ======================================

resource "azurerm_log_analytics_query_pack" "tasksQueryPack" {
  name                = "TasksQueryPack"
  resource_group_name = data.azurerm_resource_group.parent_group.name
  location            = data.azurerm_resource_group.parent_group.location
}

# Add each query separately so we can specify more details.
resource "azurerm_log_analytics_query_pack_query" "BatchDurationQuery" {
  name = "d26b7a8c-c723-441e-965b-fd591ce07649"  # must be hard-coded and unique
  query_pack_id = azurerm_log_analytics_query_pack.tasksQueryPack.id
  description = "How much time did the batch take."
  display_name = "Tasker Batch Duration"
  body = file("./modules/Tasks/TasksQueryPack/BatchDuration.kql")
  categories = [ "applications" ]
  resource_types = [
      "microsoft.insights/components",
      "microsoft.operationalinsights/workspaces"
    ]
  solutions = [ "ApplicationInsights" ]
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
  tasks_function_files = fileset("./modules/Tasks/Functions", "*.kql")
}

#
# Below are 2 different ways to deploy a KQL function:
# - to Application Insights (using azurerm_application_insights_analytics_item)
#   they will appear there under Function > "Component functions"
# - to Log Analytics  (using azurerm_log_analytics_saved_search)
#   they will appear there under Function > "Workspace functions"
#
# Here I install them ONLY in Log Analytics because that's more powerful:
# you can not only query the AppInsights logs but alo any other log. 
#


# // Instal function in Application Insights - disabled!
# data "azurerm_application_insights" "myAi" {
#   name = var.app_insights_name
#   resource_group_name = data.azurerm_resource_group.parent_group.name
# }
#
# Create a function under Application Insights for each file in the Functions folder. 
# resource "azurerm_application_insights_analytics_item" "tasksFunctions" {
#   for_each = local.tasks_function_files

#   application_insights_id = data.azurerm_application_insights.myAi.id
#   type = "function"   # must be query, function, folder or recent
#   name = "item"
#   scope = "shared"
#   function_alias = substr(basename(each.value),0, length(basename(each.value))-4) 
#   content = file("./modules/Tasks/Functions/${each.value}")
# }

# Create a function under Log Analytics for each file in the Functions folder. 
resource "azurerm_log_analytics_saved_search" "laTasksFunctions" {
  for_each = local.tasks_function_files

  name                       = substr(basename(each.value),0, length(basename(each.value))-4)
  log_analytics_workspace_id = data.azurerm_log_analytics_workspace.myWorkspace.id
  function_alias = substr(basename(each.value),0, length(basename(each.value))-4) 

  category     = "Health"
  display_name = substr(basename(each.value),0, length(basename(each.value))-4)
  query        = file("./modules/Tasks/Functions/${each.value}")
}


# ======================================
# Azure Workbooks - replacement of Azure Dashboards
# ======================================

data "azurerm_subscription" "current" {}

resource "azurerm_application_insights_workbook" "overall-health-status-workbook" {
  name                = "429a12ba-9aa9-400f-9838-adf92c496d60"
  resource_group_name = data.azurerm_resource_group.parent_group.name
  location            = data.azurerm_resource_group.parent_group.location
  description         = "Overall view of the health of the system for the Devops teams"
  display_name        = "PMA5 Overall Health Status"
  
  // In the tpl file you can use these like: ${sub_id}
  data_json =  templatefile("${path.module}/Workbooks/OverallHealthStatus.tpl",
    {
      log_analytics_name = var.log_analytics_workspace_name
      resource_group_name = data.azurerm_resource_group.parent_group.name
      sub_id     = data.azurerm_subscription.current.subscription_id
      })
}



# ======================================
# Azure portal dashboard - Deprecated, use Azure Workbook instead
# ======================================

# resource "azurerm_portal_dashboard" "machine-dashboard" {
#   name                = "machine-dashboard"
#   resource_group_name = data.azurerm_resource_group.parent_group.name
#   location            = data.azurerm_resource_group.parent_group.location
#   tags = {
#     hidden-title = "PMA5 Machine Dashboard"
#   }

#   // In the tpl file you can use these like: ${dashboard_title}
#   dashboard_properties =  templatefile("${path.module}/Dashboards/MachineDashboard.tpl",
#     {
#       dashboard_title = "PMA5 Machine Dashboard",
#       sub_id     = data.azurerm_subscription.current.subscription_id
#       })
# }
