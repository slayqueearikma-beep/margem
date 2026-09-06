variable "name_prefix" { type = string }
variable "location" { type = string }
variable "resource_group_name" { type = string }
variable "private_endpoint_subnet_id" { type = string; default = null }
variable "sku" { type = string; default = "basic" }
variable "tags" { type = map(string); default = {} }

resource "azurerm_search_service" "main" {
  name                          = "${var.name_prefix}-search"
  resource_group_name           = var.resource_group_name
  location                      = var.location
  sku                           = var.sku
  public_network_access_enabled = false
  partition_count               = var.sku == "standard" ? 1 : 1
  replica_count                 = var.sku == "standard" ? 2 : 1
  tags                          = var.tags
}

resource "azurerm_private_endpoint" "search" {
  count               = var.private_endpoint_subnet_id != null ? 1 : 0
  name                = "${var.name_prefix}-pe-search"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.private_endpoint_subnet_id

  private_service_connection {
    name                           = "search"
    private_connection_resource_id = azurerm_search_service.main.id
    subresource_names              = ["searchService"]
    is_manual_connection           = false
  }
}

output "search_service_id" { value = azurerm_search_service.main.id }
output "search_service_name" { value = azurerm_search_service.main.name }
