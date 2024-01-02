terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = "~>3.85.0"
    }
    azapi = {
      source = "azure/azapi"
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

module "tasks" {
  source  = "./modules/Tasks"
  main_resource_group = var.main_resource_group
}

module "events" {
  source  = "./modules/Events"
  main_resource_group = var.main_resource_group
}
