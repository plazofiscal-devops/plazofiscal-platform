output "cluster_name" {
  description = "Name of the AKS cluster."
  value       = azurerm_kubernetes_cluster.this.name
}

output "resource_group_name" {
  description = "Resource group of the AKS cluster."
  value       = azurerm_kubernetes_cluster.this.resource_group_name
}
