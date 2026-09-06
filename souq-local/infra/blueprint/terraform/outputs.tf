output "blueprint_status" {
  description = "Confirms blueprint is dormant or active"
  value = {
    enabled     = var.blueprint_enabled
    environment = var.environment_name
    phase       = var.activation_phase
    modules     = local.flags
  }
}

output "resource_group_name" {
  value       = try(azurerm_resource_group.blueprint[0].name, null)
  description = "Blueprint resource group (null when dormant)"
}

output "vnet_id" {
  value = try(module.networking[0].vnet_id, null)
}

output "postgresql_fqdn" {
  value     = try(module.postgresql[0].server_fqdn, null)
  sensitive = true
}

output "key_vault_uri" {
  value = try(module.keyvault[0].vault_uri, null)
}

output "aks_cluster_name" {
  value = try(module.aks[0].cluster_name, null)
}

output "frontdoor_endpoint" {
  value = try(module.frontdoor[0].endpoint_hostname, null)
}

output "apim_gateway_url" {
  value = try(module.apim[0].gateway_url, null)
}

output "log_analytics_workspace_id" {
  value = try(module.monitoring[0].log_analytics_workspace_id, null)
}
