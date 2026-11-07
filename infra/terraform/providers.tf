# Credentials come from the pipeline through OIDC. The deployer cannot register resource providers.
provider "azurerm" {
  features {}

  resource_provider_registrations = "none"
}
