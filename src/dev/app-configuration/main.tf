terraform {
  required_providers {
    akc = {				# using until AzureRM adds support for creating app configuration values
      source = "arkiaconsulting/akc"
    }
  }
}

data "azurerm_client_config" "current" {}

resource "azurerm_app_configuration" "main" {
  name                = "appcs-${var.product_name}-${var.environment}-${var.location}-001"
  resource_group_name = var.resource_group_name
  location            = var.location

  sku                 = "free" 				# free | standard
  
  identity { 
    type              = "SystemAssigned"
  }
}

# TODO - Comment back in once the terraform state file has been fixed by importing these resources

# Give current identity the relevant permission to add new key values

#resource "azurerm_role_assignment" "data-owner" {
#  scope                = azurerm_app_configuration.main.id
#  role_definition_name = "App Configuration Data Owner"
#  principal_id         = data.azurerm_client_config.current.object_id
#}

# Give relevant services access to the configuration store using their managed identities

# 1. Forum App Service (web app)

#resource "azurerm_role_assignment" "forum-app-service" {
#  scope                = azurerm_app_configuration.main.id
#  role_definition_name = "App Configuration Data Reader"
#  principal_id         = var.principal_id_forum_app_svc
#}



# TODO - Falls over with a connection error - investigate and fix, else fallback to using a null_resource executing an az cli script

# Add the sentinel keys.  Apps can watch these to keep track of when it changes so it knows when to refresh it's configuration (rather than tracking each value independently)
# https://github.com/arkiaconsulting/terraform-provider-akc
# TODO - AzureRM doesn't support doing this so temporarily using a custom provider to handle it for us

#resource "akc_key_value" "forum-sentinel-key" {
#  endpoint            = azurerm_app_configuration.main.endpoint
#  label               = var.environment
#  key                 = "Forum_SentinelKey"
#  value               = "1"
#
#  lifecycle {
#    ignore_changes = [
#      value
#    ]
#  }
#
#  depends_on = [
#    azurerm_role_assignment.data-owner
#  ]
#}