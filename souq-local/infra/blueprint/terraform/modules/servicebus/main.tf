variable "name_prefix" { type = string }
variable "location" { type = string }
variable "resource_group_name" { type = string }
variable "private_endpoint_subnet_id" { type = string; default = null }
variable "tags" { type = map(string); default = {} }

resource "azurerm_servicebus_namespace" "main" {
  name                          = "${var.name_prefix}-sb"
  location                      = var.location
  resource_group_name           = var.resource_group_name
  sku                           = "Premium"
  capacity                      = 1
  public_network_access_enabled = false
  tags                          = var.tags
}

locals {
  queues = ["email-send", "signup-otp", "image-process", "notifications", "analytics", "audit-log"]
}

resource "azurerm_servicebus_queue" "workers" {
  for_each                  = toset(local.queues)
  name                      = each.value
  namespace_id              = azurerm_servicebus_namespace.main.id
  max_delivery_count        = 10
  dead_lettering_on_message_expiration = true
  default_message_ttl       = "P1D"
}

resource "azurerm_private_endpoint" "sb" {
  count               = var.private_endpoint_subnet_id != null ? 1 : 0
  name                = "${var.name_prefix}-pe-sb"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.private_endpoint_subnet_id

  private_service_connection {
    name                           = "servicebus"
    private_connection_resource_id = azurerm_servicebus_namespace.main.id
    subresource_names              = ["namespace"]
    is_manual_connection           = false
  }
}

output "namespace_id" { value = azurerm_servicebus_namespace.main.id }
output "queue_names" { value = local.queues }
