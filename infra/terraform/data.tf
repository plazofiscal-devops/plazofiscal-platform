# The resource group survives each destroy, because it holds the deployer identity and the state.
data "azurerm_resource_group" "main" {
  name = var.resource_group_name
}
