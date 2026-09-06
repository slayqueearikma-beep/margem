variable "name_prefix" { type = string }
variable "location" { type = string }
variable "resource_group_name" { type = string }
variable "admin_login" { type = string; sensitive = true }
variable "admin_password" { type = string; sensitive = true }
variable "delegated_subnet_id" { type = string; default = null }
variable "private_dns_zone_id" { type = string; default = null }
variable "high_availability" { type = bool; default = false }
variable "tags" { type = map(string); default = {} }

resource "azurerm_postgresql_flexible_server" "main" {
  name                          = "${var.name_prefix}-pg"
  resource_group_name           = var.resource_group_name
  location                      = var.location
  version                       = "16"
  administrator_login           = var.admin_login
  administrator_password        = var.admin_password
  storage_mb                    = 131072
  sku_name                      = var.high_availability ? "GP_Standard_D4s_v3" : "GP_Standard_D2s_v3"
  backup_retention_days         = 35
  geo_redundant_backup_enabled  = var.high_availability
  public_network_access_enabled = false
  delegated_subnet_id           = var.delegated_subnet_id
  private_dns_zone_id           = var.private_dns_zone_id

  dynamic "high_availability" {
    for_each = var.high_availability ? [1] : []
    content {
      mode                      = "ZoneRedundant"
      standby_availability_zone = "2"
    }
  }

  tags = var.tags
}

resource "azurerm_postgresql_flexible_server_database" "margem" {
  name      = "margem"
  server_id = azurerm_postgresql_flexible_server.main.id
  charset   = "UTF8"
  collation = "en_US.utf8"
}

output "server_id" { value = azurerm_postgresql_flexible_server.main.id }
output "server_fqdn" { value = azurerm_postgresql_flexible_server.main.fqdn }
output "database_name" { value = azurerm_postgresql_flexible_server_database.margem.name }
