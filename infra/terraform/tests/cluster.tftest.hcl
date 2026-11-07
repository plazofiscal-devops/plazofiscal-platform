# Plan-time tests against a mocked provider. They need no Azure account.
mock_provider "azurerm" {}

variables {
  client              = "fiscal"
  project             = "plazo"
  environment         = "demo"
  resource_group_name = "fiscal-plazo-demo-rg-main"
  location            = "mexicocentral"
  availability_zones  = ["2", "3"]
  node_size           = "Standard_B2as_v2"
  node_vcpus          = 2
  node_count          = 3
}

run "pins_the_zones_and_enforces_network_policies" {
  command = plan

  assert {
    condition     = azurerm_kubernetes_cluster.this.default_node_pool[0].zones == toset(["2", "3"])
    error_message = "The node pool must use the zones of the variable."
  }

  assert {
    condition     = azurerm_kubernetes_cluster.this.network_profile[0].network_policy == "cilium"
    error_message = "The cluster must enforce network policies."
  }

  assert {
    condition     = azurerm_kubernetes_cluster.this.sku_tier == "Free"
    error_message = "The control plane must use the free tier."
  }
}

run "rejects_a_region_outside_the_policy" {
  command = plan

  variables {
    location = "eastus"
  }

  expect_failures = [var.location]
}

run "rejects_more_vcpus_than_the_quota" {
  command = plan

  variables {
    node_count = 4
  }

  expect_failures = [var.node_count]
}
