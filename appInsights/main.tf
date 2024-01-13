terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = "~>3.85.0"
    }
  }
  backend "azurerm" {
    resource_group_name  = "otelpoc"
    storage_account_name = "otelpocstorage"
    container_name       = "tfstate"
    key                  = "terraform.tfstate"
  }
}

# Azurerm Provider configuration
provider "azurerm" {
  features {}
}

module "tasks" {
  source  = "./modules/Tasks"
  main_resource_group = var.main_resource_group
  app_insights_name = var.app_insights_name
  log_analytics_workspace_name = var.log_analytics_workspace_name
}

module "events" {
  source  = "./modules/Events"
  main_resource_group = var.main_resource_group
  app_insights_name = var.app_insights_name
  log_analytics_workspace_name = var.log_analytics_workspace_name
}
