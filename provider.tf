# We strongly recommend using the required_providers block to set the
# Azure Provider source and version being used
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=4.1.0"
    }
  }
}

# Configure the Microsoft Azure Provider
provider "azurerm" {
  features {}
  # Use variables for subscription (and optionally tenant/client) so credentials
  # are provided at runtime instead of hard-coded in the repo.
  # Prefer providing service principal credentials via environment variables
  # (ARM_SUBSCRIPTION_ID, ARM_TENANT_ID, ARM_CLIENT_ID, ARM_CLIENT_SECRET)
  subscription_id = var.subscription_id
  # The following values are optional here; prefer passing them via
  # environment variables (ARM_TENANT_ID, ARM_CLIENT_ID, ARM_CLIENT_SECRET)
  # or via a secure tfvars file / secret backend. Variables are declared in
  # variables.tf so Terraform fails with a clear message if subscription_id
  # is not provided.
  tenant_id     = var.tenant_id
  client_id     = var.client_id
  client_secret = var.client_secret
}

# Create a resource group
# resource "azurerm_resource_group" "example" {
#   name     = "example-resources"
#   location = "France Central"
# }

# # Create a virtual network within the resource group
# resource "azurerm_virtual_network" "example" {
#   name                = "example-network"
#   resource_group_name = azurerm_resource_group.example.name
#   location            = azurerm_resource_group.example.location
#   address_space       = ["10.0.0.0/16"]
# }