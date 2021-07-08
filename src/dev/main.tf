terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=2.59.0"
    }
  }

  backend "azurerm" {} # injected during init call using -backend-config parameters and TF_CLI_ARGS_init env var
}

provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy = true
    }
  }
}


#data "http" "host_agent_ip" {
#  url = "https://ipv4.icanhazip.com"  # dynamic discovery of host agent's ip address for use in firewall acls
#}

locals {
  sanitized_product_name                                = lower(replace(var.product_name, "/[^A-Za-z0-9]/", ""))
  sanitized_environment                                 = lower(replace(var.environment, "/[^A-Za-z0-9]/", ""))
  sanitized_location                                    = lower(var.location)

  resource_group_name                                   = "rg-${lower(local.sanitized_product_name)}-${lower(local.sanitized_environment)}-${lower(local.sanitized_location)}-001"

  forum_db_keyvault_connection_string_reference         = "@Microsoft.KeyVault(SecretUri=https://kv-${lower(local.sanitized_product_name)}-${lower(local.sanitized_environment)}-${lower(local.sanitized_location)}.vault.azure.net/secrets/sqldb-${lower(local.sanitized_product_name)}-${lower(local.sanitized_environment)}-${lower(local.sanitized_location)}-forum-connection-string)"  
  forum_blob_keyvault_connection_string_reference       = "@Microsoft.KeyVault(SecretUri=https://kv-${lower(local.sanitized_product_name)}-${lower(local.sanitized_environment)}-${lower(local.sanitized_location)}.vault.azure.net/secrets/blobs-${lower(local.sanitized_product_name)}-${lower(local.sanitized_environment)}-${lower(local.sanitized_location)}-forum-connection-string)"
  forum_app_config_keyvault_connection_string_reference = "@Microsoft.KeyVault(SecretUri=https://kv-${lower(local.sanitized_product_name)}-${lower(local.sanitized_environment)}-${lower(local.sanitized_location)}.vault.azure.net/secrets/appcs-${lower(local.sanitized_product_name)}-${lower(local.sanitized_environment)}-${lower(local.sanitized_location)}-forum-connection-string)"
}


module "resource-group" {
  source                                                = "./resource-group"

  resource_group_name                                   = local.resource_group_name

  location                                              = var.location
}

module "storage" {
  source                                                = "./storage"

  resource_group_name                                   = module.resource-group.resource_group_name

  location                                              = var.location
  environment                                           = var.environment
  product_name                                          = var.product_name

  key_vault_id                                          = module.key-vault.key_vault_id

  log_storage_account_id                                = module.logging.log_storage_account_id

  log_analytics_workspace_resource_id                   = module.logging.log_analytics_workspace_resource_id
}

module "identities" {
  source                                                = "./identities"

  resource_group_name                                   = module.resource-group.resource_group_name

  location                                              = var.location
  environment                                           = var.environment
  product_name                                          = var.product_name
}

module "search" {
  source                                                = "./search"
 
  resource_group_name                                   = module.resource-group.resource_group_name

  location                                              = var.location
  environment                                           = var.environment
  product_name                                          = var.product_name

  log_storage_account_id                                = module.logging.log_storage_account_id

  log_analytics_workspace_resource_id                   = module.logging.log_analytics_workspace_resource_id

  forum_sql_database_name                               = module.databases.forum_database_name
  forum_database_connection_string                      = module.databases.forum_connection_string
}

module "key-vault" {
  source                                                = "./key-vault"

  #host_agent_ip_address                                 = chomp(data.http.host_agent_ip.body)
 
  resource_group_name                                   = module.resource-group.resource_group_name

  location                                              = var.location
  environment                                           = var.environment
  product_name                                          = var.product_name

  log_storage_account_id                                = module.logging.log_storage_account_id

  log_analytics_workspace_resource_id                   = module.logging.log_analytics_workspace_resource_id

  appgw_tls_certificate_path                            = var.appgw_tls_certificate_path
  appgw_tls_certificate_password                        = var.appgw_tls_certificate_password

  principal_id_forum_app_svc                            = module.app-services.principal_id_forum
  principal_id_app_configuration_svc                    = module.app-configuration.principal_id
  principal_id_app_gateway_svc                          = module.identities.principal_id_app_gateway_svc
}

module "logging" {
  source                                                = "./logging"

  resource_group_name                                   = module.resource-group.resource_group_name

  location                                              = var.location
  environment                                           = var.environment
  product_name                                          = var.product_name
}

module "virtual-network" {
  source                                                = "./virtual-network"

  resource_group_name                                   = module.resource-group.resource_group_name

  location                                              = var.location
  environment                                           = var.environment
  product_name                                          = var.product_name

  log_storage_account_id                                = module.logging.log_storage_account_id

  log_analytics_workspace_resource_id                   = module.logging.log_analytics_workspace_resource_id
}

module "app-insights" { 
  source                                                = "./app-insights"

  resource_group_name                                   = module.resource-group.resource_group_name

  location                                              = var.location
  environment                                           = var.environment
  product_name                                          = var.product_name
  
  log_storage_account_id                                = module.logging.log_storage_account_id

  log_analytics_workspace_resource_id                   = module.logging.log_analytics_workspace_resource_id
}

module "app-configuration" { 
  source                                                = "./app-configuration"

  resource_group_name                                   = module.resource-group.resource_group_name

  location                                              = var.location
  environment                                           = var.environment
  product_name                                          = var.product_name

  key_vault_id                                          = module.key-vault.key_vault_id

  principal_id_forum_app_svc                            = module.app-services.principal_id_forum
  
  log_storage_account_id                                = module.logging.log_storage_account_id

  log_analytics_workspace_resource_id                   = module.logging.log_analytics_workspace_resource_id
}

module "app-gateway" {
  source                                                = "./app-gateway"

  resource_group_name                                   = module.resource-group.resource_group_name
  virtual_network_name                                  = module.virtual-network.virtual_network_name
  network_watcher_name                                  = module.virtual-network.network_watcher_name

  managed_identity_app_gateway                          = module.identities.managed_identity_app_gateway

  key_vault_certificate_https_versionless_secret_id     = module.key-vault.key_vault_certificate_https_versionless_secret_id
  key_vault_certificate_https_name                      = module.key-vault.key_vault_certificate_https_name

  log_storage_account_id                                = module.logging.log_storage_account_id

  log_analytics_workspace_id                            = module.logging.log_analytics_workspace_id
  log_analytics_workspace_resource_id                   = module.logging.log_analytics_workspace_resource_id

  location                                              = var.location
  environment                                           = var.environment
  product_name                                          = var.product_name
}

module "app-services" {
  source                                                = "./app-services"

  resource_group_name                                   = module.resource-group.resource_group_name

  location                                              = var.location
  environment                                           = var.environment
  product_name                                          = var.product_name

  virtual_network_application_gateway_subnet_id         = module.app-gateway.virtual_network_application_gateway_subnet_id

  log_storage_account_blob_endpoint                     = module.logging.log_storage_account_blob_endpoint
  log_storage_account_connection_string                 = module.logging.log_storage_account_connection_string
  log_storage_account_container_name                    = module.logging.log_storage_account_appsvclogs_container_name
  log_storage_account_id                                = module.logging.log_storage_account_id

  log_analytics_workspace_resource_id                   = module.logging.log_analytics_workspace_resource_id

  forum_app_config_primary_endpoint                     = module.app-configuration.endpoint

  forum_primary_blob_container_endpoint                 = module.storage.forum_primary_blob_container_endpoint
  forum_primary_blob_container_resource_manager_id      = module.storage.forum_primary_blob_container_resource_manager_id
  forum_primary_blob_container_name                     = module.storage.forum_primary_blob_container_name

  forum_app_insights_instrumentation_key                = module.app-insights.forum_instrumentation_key
  forum_app_insights_connection_string                  = module.app-insights.forum_connection_string

  # There is a dependency between the key vault access policies and the app services that use it to host their secrets.  Unfortunately, we have to create access policies when the vault is 
  # created (which means we need the identities of the consuming services) otherwise we run into problems where the deployment pipeline cannot manage the secrets using these terraform scripts.  
  # Given we cannot combine assigning an access policy for the pipeline at the point of creation and using the azurerm_key_vault_access_policy resource (due to conflicts) the compromise is that 
  # we have to hard code key vault references here (the app-service config must be defined with the app-service resource as azurerm does not support a separate resource for doing so)
  # rather than feeding it in from the key-vault module.  

  forum_db_keyvault_connection_string_reference                           = local.forum_db_keyvault_connection_string_reference
  forum_primary_blob_keyvault_connection_string_reference                 = local.forum_blob_keyvault_connection_string_reference
  forum_app_config_primary_keyvault_connection_string_reference           = local.forum_app_config_keyvault_connection_string_reference
}

module "databases" {
  source                                                                  = "./databases"

  resource_group_name                                                     = module.resource-group.resource_group_name

  location                                                                = var.location
  environment                                                             = var.environment
  product_name                                                            = var.product_name

  key_vault_id                                                            = module.key-vault.key_vault_id

  sqlserver_admin_email                                                   = var.sqlserver_admin_email

  log_storage_account_blob_endpoint                                       = module.logging.log_storage_account_blob_endpoint
  log_storage_account_access_key                                          = module.logging.log_storage_account_access_key
  log_storage_account_id                                                  = module.logging.log_storage_account_id
  log_storage_account_sql_server_vulnerability_assessments_container_name = module.logging.log_storage_account_sql_server_vulnerability_assessments_container_name

  log_analytics_workspace_resource_id                                     = module.logging.log_analytics_workspace_resource_id
}

module "security_centre" {
  source                                                                  = "./security-centre"
                  
  security_center_contact_email                                           = var.security_center_contact_email
  security_center_contact_phone                                           = var.security_center_contact_phone

  log_analytics_workspace_resource_id                                     = module.logging.log_analytics_workspace_resource_id
}