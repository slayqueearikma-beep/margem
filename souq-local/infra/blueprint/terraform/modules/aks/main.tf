variable "name_prefix" { type = string }
variable "location" { type = string }
variable "resource_group_name" { type = string }
variable "backend_subnet_id" { type = string; default = null }
variable "log_analytics_id" { type = string; default = null }
variable "node_count" { type = number; default = 3 }
variable "enable_spot_pool" { type = bool; default = false }
variable "tags" { type = map(string); default = {} }

resource "azurerm_kubernetes_cluster" "main" {
  name                = "${var.name_prefix}-aks"
  location            = var.location
  resource_group_name = var.resource_group_name
  dns_prefix          = var.name_prefix
  sku_tier            = "Standard"
  tags                = var.tags

  default_node_pool {
    name                 = "api"
    vm_size              = "Standard_D4s_v5"
    node_count           = var.node_count
    vnet_subnet_id       = var.backend_subnet_id
    enable_auto_scaling  = true
    min_count            = var.node_count
    max_count            = 50
    zones                = ["1", "2", "3"]
  }

  identity { type = "SystemAssigned" }

  dynamic "oms_agent" {
    for_each = var.log_analytics_id != null ? [1] : []
    content {
      log_analytics_workspace_id = var.log_analytics_id
    }
  }

  network_profile {
    network_plugin    = "azure"
    network_policy    = "azure"
    load_balancer_sku = "standard"
    outbound_type     = "userAssignedNATGateway"
  }

  azure_policy_enabled = true
}

resource "azurerm_kubernetes_cluster_node_pool" "workers" {
  count                 = var.enable_spot_pool ? 1 : 0
  name                  = "workers"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.main.id
  vm_size               = "Standard_D2s_v5"
  node_count            = 0
  enable_auto_scaling   = true
  min_count             = 0
  max_count             = 20
  vnet_subnet_id        = var.backend_subnet_id
  priority              = "Spot"
  eviction_policy       = "Delete"
  spot_max_price        = -1
  zones                 = ["1", "2", "3"]
}

output "cluster_id" { value = azurerm_kubernetes_cluster.main.id }
output "cluster_name" { value = azurerm_kubernetes_cluster.main.name }
output "kube_config" {
  value     = azurerm_kubernetes_cluster.main.kube_config_raw
  sensitive = true
}
output "internal_lb_fqdn" {
  value = "${var.name_prefix}-api.internal"
  description = "Placeholder — set after K8s Service deploy"
}
