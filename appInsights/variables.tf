variable "main_resource_group" {
  description = "Name of resource group to deploy to"
  type        = string
  default     = "otelpoc"
}
variable "app_insights_name" {
  description = "Name of the Application Insights instance"
  type        = string
  default     = "otelpoc-ai"
}
variable "log_analytics_workspace_name" {
  description = "Name of the Log Analytics workspace"
  type        = string
  default     = "otelpoc-la"
}