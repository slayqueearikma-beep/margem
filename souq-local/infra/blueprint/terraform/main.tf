locals {
  is_active = var.blueprint_enabled && var.subscription_id != ""

  flags = {
    networking      = local.is_active && try(var.module_flags.networking, false)
    keyvault        = local.is_active && try(var.module_flags.keyvault, false)
    postgresql      = local.is_active && try(var.module_flags.postgresql, false)
    storage         = local.is_active && try(var.module_flags.storage, false)
    monitoring      = local.is_active && try(var.module_flags.monitoring, false)
    security        = local.is_active && try(var.module_flags.security, false)
    aks             = local.is_active && try(var.module_flags.aks, false)
    appservice      = local.is_active && try(var.module_flags.appservice, false)
    apim            = local.is_active && try(var.module_flags.apim, false)
    frontdoor       = local.is_active && try(var.module_flags.frontdoor, false)
    redis           = local.is_active && try(var.module_flags.redis, false)
    servicebus      = local.is_active && try(var.module_flags.servicebus, false)
    messaging       = local.is_active && try(var.module_flags.messaging, false)
    search          = local.is_active && try(var.module_flags.search, false)
    ai              = local.is_active && try(var.module_flags.ai, false)
    ddos_protection = local.is_active && try(var.module_flags.ddos_protection, false)
    firewall        = local.is_active && try(var.module_flags.firewall, false)
    multi_region    = local.is_active && try(var.module_flags.multi_region, false)
  }

  name_prefix = "${var.name_prefix}-${var.environment_name}"

  tags = merge(var.common_tags, {
    environment      = var.environment_name
    blueprint_phase  = var.activation_phase
    blueprint_active = tostring(var.blueprint_enabled)
  })
}

# Dormant marker — optional single RG when blueprint_enabled=true but no modules
# Allows validating Terraform without deploying full stack
resource "azurerm_resource_group" "blueprint" {
  count    = local.is_active ? 1 : 0
  name     = "rg-${local.name_prefix}-blueprint"
  location = var.location
  tags     = local.tags
}

module "networking" {
  source = "./modules/networking"
  count  = local.flags.networking ? 1 : 0

  name_prefix          = local.name_prefix
  location             = var.location
  resource_group_name  = azurerm_resource_group.blueprint[0].name
  vnet_address_space   = var.vnet_address_space
  enable_ddos          = local.flags.ddos_protection
  enable_firewall      = local.flags.firewall
  enable_bastion       = true
  enable_nat_gateway   = true
  tags                 = local.tags
}

module "monitoring" {
  source = "./modules/monitoring"
  count  = local.flags.monitoring ? 1 : 0

  name_prefix         = local.name_prefix
  location            = var.location
  resource_group_name = azurerm_resource_group.blueprint[0].name
  environment_name    = var.environment_name
  tags                = local.tags
}

module "keyvault" {
  source = "./modules/keyvault"
  count  = local.flags.keyvault ? 1 : 0

  name_prefix              = local.name_prefix
  location                 = var.location
  resource_group_name      = azurerm_resource_group.blueprint[0].name
  tenant_id                = data.azurerm_client_config.current.tenant_id
  private_endpoint_subnet_id = local.flags.networking ? module.networking[0].private_endpoints_subnet_id : null
  log_analytics_id         = local.flags.monitoring ? module.monitoring[0].log_analytics_workspace_id : null
  purge_protection         = var.environment_name == "production"
  tags                     = local.tags

  depends_on = [module.networking]
}

module "postgresql" {
  source = "./modules/postgresql"
  count  = local.flags.postgresql ? 1 : 0

  name_prefix         = local.name_prefix
  location            = var.location
  resource_group_name = azurerm_resource_group.blueprint[0].name
  admin_login         = var.postgres_admin_login
  admin_password      = var.postgres_admin_password
  delegated_subnet_id = local.flags.networking ? module.networking[0].database_subnet_id : null
  private_dns_zone_id = local.flags.networking ? module.networking[0].postgres_private_dns_zone_id : null
  high_availability   = var.environment_name == "production"
  tags                = local.tags

  depends_on = [module.networking]
}

module "storage" {
  source = "./modules/storage"
  count  = local.flags.storage ? 1 : 0

  name_prefix              = local.name_prefix
  location                 = var.location
  resource_group_name      = azurerm_resource_group.blueprint[0].name
  private_endpoint_subnet_id = local.flags.networking ? module.networking[0].private_endpoints_subnet_id : null
  geo_redundant            = var.environment_name == "production"
  tags                     = local.tags

  depends_on = [module.networking]
}

module "redis" {
  source = "./modules/redis"
  count  = local.flags.redis ? 1 : 0

  name_prefix              = local.name_prefix
  location                 = var.location
  resource_group_name      = azurerm_resource_group.blueprint[0].name
  private_endpoint_subnet_id = local.flags.networking ? module.networking[0].private_endpoints_subnet_id : null
  sku_name                 = var.environment_name == "production" ? "Standard" : "Basic"
  tags                     = local.tags

  depends_on = [module.networking]
}

module "servicebus" {
  source = "./modules/servicebus"
  count  = local.flags.servicebus ? 1 : 0

  name_prefix              = local.name_prefix
  location                 = var.location
  resource_group_name      = azurerm_resource_group.blueprint[0].name
  private_endpoint_subnet_id = local.flags.networking ? module.networking[0].private_endpoints_subnet_id : null
  tags                     = local.tags

  depends_on = [module.networking]
}

module "aks" {
  source = "./modules/aks"
  count  = local.flags.aks ? 1 : 0

  name_prefix         = local.name_prefix
  location            = var.location
  resource_group_name = azurerm_resource_group.blueprint[0].name
  backend_subnet_id   = local.flags.networking ? module.networking[0].backend_subnet_id : null
  log_analytics_id    = local.flags.monitoring ? module.monitoring[0].log_analytics_workspace_id : null
  node_count          = var.environment_name == "production" ? 3 : 2
  enable_spot_pool    = var.environment_name != "production"
  tags                = local.tags

  depends_on = [module.networking, module.monitoring]
}

module "apim" {
  source = "./modules/apim"
  count  = local.flags.apim ? 1 : 0

  name_prefix         = local.name_prefix
  location            = var.location
  resource_group_name = azurerm_resource_group.blueprint[0].name
  publisher_email     = "platform@dribex.ma"
  sku_name            = var.environment_name == "production" ? "Standard_1" : "Consumption_0"
  backend_url         = local.flags.aks ? "http://${module.aks[0].internal_lb_fqdn}" : ""
  jwt_issuer          = "margem-api"
  tags                = local.tags

  depends_on = [module.aks]
}

module "frontdoor" {
  source = "./modules/frontdoor"
  count  = local.flags.frontdoor ? 1 : 0

  name_prefix    = local.name_prefix
  resource_group_name = azurerm_resource_group.blueprint[0].name
  domain_name    = var.domain_name
  backend_host   = local.flags.apim ? module.apim[0].gateway_url : ""
  tags           = local.tags

  depends_on = [module.apim]
}

module "search" {
  source = "./modules/search"
  count  = local.flags.search ? 1 : 0

  name_prefix              = local.name_prefix
  location                 = var.location
  resource_group_name      = azurerm_resource_group.blueprint[0].name
  private_endpoint_subnet_id = local.flags.networking ? module.networking[0].private_endpoints_subnet_id : null
  sku                      = var.environment_name == "production" ? "standard" : "basic"
  tags                     = local.tags

  depends_on = [module.networking]
}

module "ai" {
  source = "./modules/ai"
  count  = local.flags.ai ? 1 : 0

  name_prefix         = local.name_prefix
  location            = var.location
  resource_group_name = azurerm_resource_group.blueprint[0].name
  tags                = local.tags
}

module "security" {
  source = "./modules/security"
  count  = local.flags.security ? 1 : 0

  name_prefix         = local.name_prefix
  location            = var.location
  resource_group_name = azurerm_resource_group.blueprint[0].name
  log_analytics_id    = local.flags.monitoring ? module.monitoring[0].log_analytics_workspace_id : null
  tags                = local.tags

  depends_on = [module.monitoring]
}

module "appservice" {
  source = "./modules/appservice"
  count  = local.flags.appservice ? 1 : 0

  name_prefix         = local.name_prefix
  location            = var.location
  resource_group_name = azurerm_resource_group.blueprint[0].name
  backend_subnet_id   = local.flags.networking ? module.networking[0].backend_subnet_id : null
  log_analytics_id    = local.flags.monitoring ? module.monitoring[0].log_analytics_workspace_id : null
  tags                = local.tags

  depends_on = [module.networking, module.monitoring]
}
