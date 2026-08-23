variable "name_prefix" { type = string }
variable "location" { type = string }
variable "resource_group_name" { type = string }
variable "private_endpoint_subnet_id" { type = string; default = null }
variable "sku_name" { type = string; default = "Standard" }
variable "tags" { type = map(string); default = {} }

resource "azurerm_redis_cache" "main" {
  name                          = "${var.name_prefix}-redis"
  location                      = var.location
  resource_group_name           = var.resource_group_name
  capacity                      = var.sku_name == "Premium" ? 1 : 0
  family                        = var.sku_name == "Premium" ? "P" : "C"
  sku_name                      = var.sku_name
  minimum_tls_version           = "1.2"
  public_network_access_enabled = false
  tags                          = var.tags

  redis_configuration {
    maxmemory_policy = "allkeys-lru"
  }
}

resource "azurerm_private_endpoint" "redis" {
  count               = var.private_endpoint_subnet_id != null ? 1 : 0
  name                = "${var.name_prefix}-pe-redis"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.private_endpoint_subnet_id

  private_service_connection {
    name                           = "redis"
    private_connection_resource_id = azurerm_redis_cache.main.id
    subresource_names              = ["redisCache"]
    is_manual_connection           = false
  }
}

output "redis_id" { value = azurerm_redis_cache.main.id }
output "redis_hostname" { value = azurerm_redis_cache.main.hostname }
output "redis_ssl_port" { value = azurerm_redis_cache.main.ssl_port }
