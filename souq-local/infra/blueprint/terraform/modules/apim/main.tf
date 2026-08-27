variable "name_prefix" { type = string }
variable "location" { type = string }
variable "resource_group_name" { type = string }
variable "publisher_email" { type = string }
variable "sku_name" { type = string; default = "Consumption_0" }
variable "backend_url" { type = string; default = "" }
variable "jwt_issuer" { type = string; default = "margem-api" }
variable "tags" { type = map(string); default = {} }

resource "azurerm_api_management" "main" {
  name                = "${var.name_prefix}-apim"
  location            = var.location
  resource_group_name = var.resource_group_name
  publisher_name      = "Dribex"
  publisher_email     = var.publisher_email
  sku_name            = var.sku_name
  tags                = var.tags
}

resource "azurerm_api_management_api" "margem" {
  name                  = "margem-api"
  resource_group_name   = var.resource_group_name
  api_management_name   = azurerm_api_management.main.name
  revision              = "1"
  display_name          = "Dribex API"
  path                  = ""
  protocols             = ["https"]
  subscription_required = false
}

resource "azurerm_api_management_backend" "api" {
  count               = var.backend_url != "" ? 1 : 0
  name                = "margem-backend"
  resource_group_name = var.resource_group_name
  api_management_name = azurerm_api_management.main.name
  protocol            = "http"
  url                 = var.backend_url
}

# Policy: rate limit + JWT validate + CORS — see policies/api-policy.xml
resource "azurerm_api_management_api_policy" "margem" {
  api_name            = azurerm_api_management_api.margem.name
  api_management_name = azurerm_api_management.main.name
  resource_group_name = var.resource_group_name

  xml_content = file("${path.module}/policies/api-policy.xml")
}

output "apim_id" { value = azurerm_api_management.main.id }
output "gateway_url" { value = azurerm_api_management.main.gateway_url }
