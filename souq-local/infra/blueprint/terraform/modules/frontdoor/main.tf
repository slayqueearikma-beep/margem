variable "name_prefix" { type = string }
variable "resource_group_name" { type = string }
variable "domain_name" { type = string }
variable "backend_host" { type = string; default = "" }
variable "tags" { type = map(string); default = {} }

resource "azurerm_cdn_frontdoor_profile" "main" {
  name                = "${var.name_prefix}-afd"
  resource_group_name = var.resource_group_name
  sku_name            = "Premium_AzureFrontDoor"
  tags                = var.tags
}

resource "azurerm_cdn_frontdoor_endpoint" "main" {
  name                     = "${var.name_prefix}-endpoint"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.main.id
  tags                     = var.tags
}

resource "azurerm_cdn_frontdoor_origin_group" "api" {
  count                    = var.backend_host != "" ? 1 : 0
  name                     = "api-origins"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.main.id

  load_balancing {
    sample_size                 = 4
    successful_samples_required = 3
  }

  health_probe {
    path                = "/health"
    protocol            = "Https"
    interval_in_seconds = 30
  }
}

resource "azurerm_cdn_frontdoor_origin" "apim" {
  count                         = var.backend_host != "" ? 1 : 0
  name                          = "apim-origin"
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.api[0].id
  enabled                       = true
  host_name                     = replace(var.backend_host, "https://", "")
  http_port                     = 80
  https_port                    = 443
  origin_host_header            = replace(var.backend_host, "https://", "")
  priority                      = 1
  weight                        = 1000
  certificate_name_check_enabled = true
}

resource "azurerm_cdn_frontdoor_firewall_policy" "waf" {
  name                              = "${replace(var.name_prefix, "-", "")}waf"
  resource_group_name               = var.resource_group_name
  sku_name                          = "Premium_AzureFrontDoor"
  enabled                           = true
  mode                              = "Prevention"
  tags                              = var.tags

  managed_rule {
    type    = "Microsoft_DefaultRuleSet"
    version = "2.1"
    action  = "Block"
  }

  managed_rule {
    type    = "Microsoft_BotManagerRuleSet"
    version = "1.0"
    action  = "Block"
  }
}

resource "azurerm_cdn_frontdoor_security_policy" "waf" {
  name                     = "${var.name_prefix}-waf-policy"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.main.id

  security_policies {
    firewall {
      cdn_frontdoor_firewall_policy_id = azurerm_cdn_frontdoor_firewall_policy.waf.id
      association {
        domain {
          cdn_frontdoor_domain_id = azurerm_cdn_frontdoor_endpoint.main.id
        }
        patterns_to_match = ["/*"]
      }
    }
  }
}

output "profile_id" { value = azurerm_cdn_frontdoor_profile.main.id }
output "endpoint_hostname" { value = azurerm_cdn_frontdoor_endpoint.main.host_name }
