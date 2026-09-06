# Bridge module — Azure App Service for Containers
# Intermediate step between Container Apps and AKS. Same margem-api image.

variable "name_prefix" { type = string }
variable "location" { type = string }
variable "resource_group_name" { type = string }
variable "backend_subnet_id" { type = string; default = null }
variable "log_analytics_id" { type = string; default = null }
variable "tags" { type = map(string); default = {} }

resource "azurerm_service_plan" "main" {
  name                = "${var.name_prefix}-asp"
  location            = var.location
  resource_group_name = var.resource_group_name
  os_type             = "Linux"
  sku_name            = "P1v3"
  tags                = var.tags
}

resource "azurerm_linux_web_app" "api" {
  name                = "${var.name_prefix}-api"
  location            = var.location
  resource_group_name = var.resource_group_name
  service_plan_id     = azurerm_service_plan.main.id
  https_only          = true
  tags                = var.tags

  site_config {
    minimum_tls_version = "1.2"
    always_on           = true
    health_check_path   = "/ready"
  }

  identity { type = "SystemAssigned" }
}

output "default_hostname" { value = azurerm_linux_web_app.api.default_hostname }
output "principal_id" { value = azurerm_linux_web_app.api.identity[0].principal_id }
