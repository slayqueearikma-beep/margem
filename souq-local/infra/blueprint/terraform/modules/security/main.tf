variable "name_prefix" { type = string }
variable "location" { type = string }
variable "resource_group_name" { type = string }
variable "log_analytics_id" { type = string; default = null }
variable "tags" { type = map(string); default = {} }

data "azurerm_subscription" "current" {}

resource "azurerm_security_center_subscription_pricing" "defender" {
  tier          = "Standard"
  resource_type = "VirtualMachines"
}

resource "azurerm_security_center_subscription_pricing" "containers" {
  tier          = "Standard"
  resource_type = "Containers"
}

resource "azurerm_security_center_subscription_pricing" "storage" {
  tier          = "Standard"
  resource_type = "StorageAccounts"
}

resource "azurerm_security_center_subscription_pricing" "keyvault" {
  tier          = "Standard"
  resource_type = "KeyVaults"
}

resource "azurerm_security_center_subscription_pricing" "sql" {
  tier          = "Standard"
  resource_type = "SqlServers"
}

resource "azurerm_sentinel_log_analytics_workspace_onboarding" "main" {
  count                                 = var.log_analytics_id != null ? 1 : 0
  workspace_id                          = var.log_analytics_id
  customer_managed_key_enabled          = false
}

resource "azurerm_resource_group_policy_assignment" "cis" {
  name                 = "${var.name_prefix}-cis-assignment"
  resource_group_id    = "/subscriptions/${data.azurerm_subscription.current.subscription_id}/resourceGroups/${var.resource_group_name}"
  policy_definition_id = "/providers/Microsoft.Authorization/policySetDefinitions/1f3afdf9-d0c9-4c3d-847f-89da613e70a8"
  display_name         = "CIS Azure Foundations"
}

output "sentinel_enabled" {
  value = var.log_analytics_id != null
}
