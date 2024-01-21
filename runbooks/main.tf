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
    container_name       = "tfstate-runbooks"
    key                  = "terraform.tfstate"
  }
}


# Azurerm Provider configuration
provider "azurerm" {
  features {}
}

// Get a reference to the resource group
data "azurerm_resource_group" "parent_group" {
  name = var.main_resource_group
}


// Get a reference to the Automation Account for Standard Operating Procedures runbooks.
data "azurerm_automation_account" "sop_aa" {
  name = "standard-operating-proc-aa"
  resource_group_name     = data.azurerm_resource_group.parent_group.name
}

// Ensure the necessary Python packages are installed in the Automation Account
resource "azurerm_automation_python3_package" "requirements_azure_identity" {
  name = "azure-identity"
  resource_group_name     = data.azurerm_resource_group.parent_group.name
  automation_account_name = data.azurerm_automation_account.sop_aa.name
  content_uri             = "https://files.pythonhosted.org/packages/30/10/5dbf755b368d10a28d55b06ac1f12512a13e88874a23db82defdea9a8cd9/azure_identity-1.15.0-py3-none-any.whl"
#   content_version         = "2.31.0"
#   hash_algorithm          = "sha256"
#   hash_value              = "942c5a758f98d790eaed1a29cb6eefc7ffb0d1cf7af05c3d2791656dbd6ad1e1"
}

resource "azurerm_automation_python3_package" "requirements_azure_core" {
  name = "azure-core"
  resource_group_name     = data.azurerm_resource_group.parent_group.name
  automation_account_name = data.azurerm_automation_account.sop_aa.name
  content_uri             = "https://files.pythonhosted.org/packages/9c/f8/1cf23a75cb8c2755c539ac967f3a7f607887c4979d073808134803720f0f/azure_core-1.29.5-py3-none-any.whl"
}

resource "azurerm_automation_python3_package" "requirements_typing_extensions" {
  name = "typing_extensions"
  resource_group_name     = data.azurerm_resource_group.parent_group.name
  automation_account_name = data.azurerm_automation_account.sop_aa.name
  content_uri             = "https://files.pythonhosted.org/packages/24/21/7d397a4b7934ff4028987914ac1044d3b7d52712f30e2ac7a2ae5bc86dd0/typing_extensions-4.8.0-py3-none-any.whl"
}

resource "azurerm_automation_python3_package" "requirements_msal" {
  name = "msal"
  resource_group_name     = data.azurerm_resource_group.parent_group.name
  automation_account_name = data.azurerm_automation_account.sop_aa.name
  content_uri             = "https://files.pythonhosted.org/packages/2a/45/d80a35ce701c1b3b53ab57a585813636acba39f3a8ed87ac01e0f1dfa3c1/msal-1.25.0-py2.py3-none-any.whl"
}



# Create a set of all runbook files in the directory.
locals {
  python_runbook_files = fileset("./std_operating_procedures", "*.py")
  powershell_runbook_files = fileset("./std_operating_procedures", "*.ps1")
}

#
# Create a function under Log Analytics for each file in the Functions folder. 
#

// Deploy a Python runbook to restart a run for Events
resource "azurerm_automation_runbook" "sop_python_runbook" {
  for_each = local.python_runbook_files
  
  name                    = substr(basename(each.value),0, length(basename(each.value))-3)
  location                = data.azurerm_resource_group.parent_group.location
  resource_group_name     = data.azurerm_resource_group.parent_group.name
  automation_account_name = data.azurerm_automation_account.sop_aa.name
  log_verbose             = "false"
  log_progress            = "true"
  description             = "Standard Operating Procedure: ${replace(substr(basename(each.value),0, length(basename(each.value))-3),"_","")}"
  runbook_type            = "Python3"

  content = file("${path.module}/std_operating_procedures/${each.value}")
}

// Deploy a PowerShell runbook to restart a run for Events
resource "azurerm_automation_runbook" "sop_powershell_runbooks" {
  for_each = local.powershell_runbook_files
  
  name                    = substr(basename(each.value),0, length(basename(each.value))-4)
  location                = data.azurerm_resource_group.parent_group.location
  resource_group_name     = data.azurerm_resource_group.parent_group.name
  automation_account_name = data.azurerm_automation_account.sop_aa.name
  log_verbose             = "false"
  log_progress            = "true"
  description             = "Standard Operating Procedure"
  runbook_type            = "PowerShell"

  content = file("${path.module}/std_operating_procedures/${each.value}")
}

#
# Create webhook for 1 or more runbooks
#

data "local_file" "runbook_manual_run" {
  filename = "${path.module}/std_operating_procedures/ManuallyStartEventsRun.py"
}

# Define the details of a webhook that is valid for 1 year
locals {
  runbook_name = "ManuallyStartEventsRun"
  webhook_name = "webhook-sop-runbook-manual-run"
  webhook_expiry_date = timeadd(plantimestamp(),"8640h") # max. 360 days

  actionGroupName = "On-Call Team" 
  actionGroupEmail = "test@example.com"
}

resource "azurerm_automation_webhook" "sop_runbook_manual_run" {
  name                    = local.webhook_name
  resource_group_name     = data.azurerm_resource_group.parent_group.name
  automation_account_name = data.azurerm_automation_account.sop_aa.name
  expiry_time             = local.webhook_expiry_date
  enabled                 = true
  runbook_name            = local.runbook_name
  parameters = {
    input = "WEBHOOKDATA"
  }
}

// Store the webhook credentials in the key vault

// Get reference to the Key Vault
data "azurerm_key_vault" kv {
  name = "${data.azurerm_resource_group.parent_group.name}-kv"
  resource_group_name     = data.azurerm_resource_group.parent_group.name
}

// Store the reference in the key vault
resource "azurerm_key_vault_secret" "webhook_secret_sop_runbook_manual_run" {
  name         = local.webhook_name
  value        = azurerm_automation_webhook.sop_runbook_manual_run.uri
  key_vault_id = data.azurerm_key_vault.kv.id
}


/*
These items will not be used.

// Separate object for the credentials, to be used as parameter for the PowerShell runbook
resource "azurerm_automation_credential" "log_storage_credentials" {
  name                    = "log-storage-credentials"
  resource_group_name     = data.azurerm_resource_group.parent_group.name
  automation_account_name = azurerm_automation_account.sop_aa.name
  username                = azurerm_storage_account.log_storage.name
  password                = azurerm_storage_account.log_storage.primary_access_key
}

// We create a schedule first and then link it to the runbook using a job schedule.
// We’re again assumming a storage account was earlier created named log_container
// We also need to first get your subscription ID using the snippet below:
data "azurerm_client_config" "current" {
}

// Use this to define a schedule
resource "azurerm_automation_schedule" "log_cleaup_schedule" {
  name                    = "log-cleanup-schedule"
  resource_group_name     = data.azurerm_resource_group.parent_group.name
  automation_account_name = azurerm_automation_account.sop_aa.name
  frequency               = "Week"
  interval                = 1
  description             = "Schedule to cleanup logs each week"
}

// Apply the schedule to a specific job
resource "azurerm_automation_job_schedule" "schedule_clean_log_job" {
  resource_group_name     = data.azurerm_resource_group.parent_group.name
  automation_account_name = azurerm_automation_account.sop_aa.name
  schedule_name           = azurerm_automation_schedule.log_cleaup_schedule.name
  runbook_name            = azurerm_automation_runbook.sop_events_manual_run_runbook.name
#  As opposed to PowerShell runbooks, Python runbooks only support positional parameters.
#   parameters = {
#     storagecredentialsname = azurerm_automation_credential.log_storage_credentials.name
#     storagecontainername = azurerm_storage_container.log_container.name
#     subscriptionid = data.azurerm_client_config.current.client_id
#   }
}

*/

#
# Now create an alert that will start a Runbook
#

// Create a group to define what to do: send an email and start a runbook
resource "azurerm_monitor_action_group" "myActionGroup" {
  name = local.actionGroupName
  short_name = "oncallteam"
  resource_group_name = data.azurerm_resource_group.parent_group.name
  enabled = true

  email_receiver {
    name          = local.actionGroupName
    email_address = local.actionGroupEmail
    use_common_alert_schema = true
  }

  automation_runbook_receiver {
    name = "myRunbookReceiver"
    automation_account_id = data.azurerm_automation_account.sop_aa.id
    is_global_runbook = false
    runbook_name = local.runbook_name
    webhook_resource_id = "${data.azurerm_automation_account.sop_aa.id}/webHooks/${local.webhook_name}"
    service_uri = data.azurerm_key_vault_secret.webhook_secret_sop_runbook_manual_run.value
  }
}

//
resource "azurerm_monitor_action_rule_action_group" "alertRule" {
  name = "alertRuleName"
  resource_group_name = data.azurerm_resource_group.parent_group.name
  action_group_id = azurerm_monitor_action_group.myActionGroup.id
  enabled = true

  condition {
    monitor_service {
      operator = "Equals"
      values = [
        "Azure Backup"
      ] 
    }
  }

  scope {
    type         = "ResourceGroup"
    resource_ids = [data.azurerm_resource_group.parent_group.id]
  }
}
