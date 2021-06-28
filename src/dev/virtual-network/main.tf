resource "azurerm_network_watcher" "main" {
  name                      = "nww-${lower(var.product_name)}-${lower(var.environment)}-${lower(var.location)}-001"
  location                  = var.location
  resource_group_name       = var.resource_group_name
}

resource "azurerm_virtual_network" "main" {
  name                      = "vnet-${lower(var.product_name)}-${lower(var.environment)}-${lower(var.location)}-001"
  location                  = azurerm_network_watcher.main.location
  resource_group_name       = azurerm_network_watcher.main.resource_group_name
  address_space             = ["10.0.0.0/16"]
}

