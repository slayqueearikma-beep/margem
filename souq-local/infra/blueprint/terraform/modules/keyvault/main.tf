variable "name_prefix" { type = string }
variable "location" { type = string }
variable "resource_group_name" { type = string }
variable "tenant_id" { type = string }
variable "private_endpoint_subnet_id" { type = string; default = null }
variable "log_analytics_id" { type = string; default = null }
variable "purge_protection" { type = bool; default = true }
variable "tags" { type = map(string); default = {} }

resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

resource "azurerm_key_vault" "main" {
  name                       = substr("${var.name_prefix}-kv-${random_string.suffix.result}", 0, 24)
  location                   = var.location
  resource_group_name        = var.resource_group_name
  tenant_id                  = var.tenant_id
  sku_name                   = "premium"
  soft_delete_retention_days = 90
  purge_protection_enabled   = var.purge_protection
  rbac_authorization_enabled = true
  public_network_access_enabled = false
  tags                       = var.tags
}

resource "azurerm_private_endpoint" "kv" {
  count               = var.private_endpoint_subnet_id != null ? 1 : 0
  name                = "${var.name_prefix}-pe-kv"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.private_endpoint_subnet_id

  private_service_connection {
    name                           = "kv"
    private_connection_resource_id = azurerm_key_vault.main.id
    subresource_names              = ["vault"]
    is_manual_connection           = false
  }
}

output "vault_id" { value = azurerm_key_vault.main.id }
output "vault_uri" { value = azurerm_key_vault.main.vault_uri }
