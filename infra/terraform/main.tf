resource "azurerm_kubernetes_cluster" "this" {
  name                = local.cluster_name
  location            = var.location
  resource_group_name = data.azurerm_resource_group.main.name
  dns_prefix          = local.cluster_name
  node_resource_group = "${local.governance_prefix}-rg-nodes"
  sku_tier            = "Free"
  tags                = local.tags

  default_node_pool {
    name       = "system"
    vm_size    = var.node_size
    node_count = var.node_count
    zones      = var.availability_zones
    os_sku     = "AzureLinux"
    tags       = local.tags
  }

  # Nodes stay fixed, since the quota leaves no room for automatic provisioning.
  node_provisioning_profile {
    mode = "Manual"
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin      = "azure"
    network_plugin_mode = "overlay"
    network_data_plane  = "cilium"
    network_policy      = "cilium"
  }
}
