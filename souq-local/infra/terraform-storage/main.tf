resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

locals {
  name_prefix  = "margem-home-${var.subscription_alias}"
  storage_name = substr(replace("${local.name_prefix}st${random_string.suffix.result}", "-", ""), 0, 24)
}

resource "azurerm_resource_group" "rg" {
  name     = "rg-${local.name_prefix}"
  location = var.location
  tags     = { project = "margem", tier = "home-blob-only" }
}

resource "azurerm_storage_account" "media" {
  name                     = local.storage_name
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  min_tls_version          = "TLS1_2"
  https_traffic_only_enabled = true

  tags = azurerm_resource_group.rg.tags
}

resource "azurerm_storage_container" "media" {
  name                  = "margem-media"
  storage_account_id    = azurerm_storage_account.media.id
  container_access_type = "private"
}
