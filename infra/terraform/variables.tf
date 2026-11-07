variable "client" {
  description = "Client code, used in names and tags."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]{1,10}$", var.client))
    error_message = "client must be 1 to 10 lowercase alphanumeric characters."
  }
}

variable "project" {
  description = "Project code, used in names and tags."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]{1,15}$", var.project))
    error_message = "project must be 1 to 15 lowercase alphanumeric characters."
  }
}

variable "environment" {
  description = "Deployment environment."
  type        = string

  validation {
    condition     = contains(["demo"], var.environment)
    error_message = "environment must be demo."
  }
}

variable "resource_group_name" {
  description = "Resource group created by the bootstrap."
  type        = string

  validation {
    condition     = length(var.resource_group_name) > 0
    error_message = "resource_group_name cannot be empty."
  }
}

variable "location" {
  description = "Azure region. The subscription policy allows only these five."
  type        = string

  validation {
    condition     = contains(["mexicocentral", "southcentralus", "eastus2", "westus3", "brazilsouth"], var.location)
    error_message = "location must be a region the subscription policy allows."
  }
}

variable "availability_zones" {
  description = "Zones of the node pool. Sizes are restricted per zone, so they are always explicit."
  type        = list(string)

  validation {
    condition     = length(var.availability_zones) > 0
    error_message = "availability_zones cannot be empty."
  }
}

variable "node_size" {
  description = "Size of the nodes."
  type        = string

  validation {
    condition     = can(regex("^Standard_", var.node_size))
    error_message = "node_size must be an Azure size name."
  }
}

variable "node_vcpus" {
  description = "vCPUs of one node, used to check the regional quota."
  type        = number

  validation {
    condition     = var.node_vcpus > 0
    error_message = "node_vcpus must be positive."
  }
}

variable "node_count" {
  description = "Number of nodes. The subscription allows 6 vCPU per region."
  type        = number

  validation {
    condition     = var.node_count >= 1 && var.node_count * var.node_vcpus <= 6
    error_message = "node_count times node_vcpus cannot exceed the quota of 6 vCPU."
  }
}
