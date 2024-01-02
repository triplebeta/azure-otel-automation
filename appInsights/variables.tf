variable "main_resource_group" {
  description = "Name of resource group to deploy to"
  type        = string
  default     = "pma5-poc"
}
variable "app_insights_name" {
  description = "Name of the Application Insights instance"
  type        = string
  default     = "pma5poc-ai"
}