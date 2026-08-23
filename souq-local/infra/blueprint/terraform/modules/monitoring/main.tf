variable "name_prefix" { type = string }
variable "location" { type = string }
variable "resource_group_name" { type = string }
variable "environment_name" { type = string }
variable "tags" { type = map(string); default = {} }

resource "azurerm_log_analytics_workspace" "main" {
  name                = "${var.name_prefix}-logs"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "PerGB2018"
  retention_in_days   = var.environment_name == "production" ? 90 : 30
  tags                = var.tags
}

resource "azurerm_application_insights" "api" {
  name                = "${var.name_prefix}-appi"
  location            = var.location
  resource_group_name = var.resource_group_name
  workspace_id        = azurerm_log_analytics_workspace.main.id
  application_type    = "web"
  tags                = var.tags
}

resource "azurerm_monitor_action_group" "platform" {
  name                = "${var.name_prefix}-ag"
  resource_group_name = var.resource_group_name
  short_name          = "margempl"
  tags                = var.tags
}

resource "azurerm_monitor_metric_alert" "api_5xx" {
  name                = "${var.name_prefix}-alert-5xx"
  resource_group_name = var.resource_group_name
  scopes              = [azurerm_application_insights.api.id]
  description         = "Elevated server errors"
  severity            = 2
  frequency           = "PT5M"
  window_size         = "PT5M"

  criteria {
    metric_namespace = "Microsoft.Insights/components"
    metric_name      = "requests/failed"
    aggregation      = "Count"
    operator         = "GreaterThan"
    threshold        = 50
  }

  action {
    action_group_id = azurerm_monitor_action_group.platform.id
  }

  tags = var.tags
}

output "log_analytics_workspace_id" { value = azurerm_log_analytics_workspace.main.id }
output "application_insights_connection_string" {
  value     = azurerm_application_insights.api.connection_string
  sensitive = true
}
output "application_insights_instrumentation_key" {
  value     = azurerm_application_insights.api.instrumentation_key
  sensitive = true
}
