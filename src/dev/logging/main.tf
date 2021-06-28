resource "azurerm_storage_account" "logs" {
  name                      = "sa${var.product_name}${var.environment}${var.location}logs"
  resource_group_name       = var.resource_group_name
  location                  = var.location

  account_tier              = "Standard"
  account_kind              = "StorageV2"
  account_replication_type  = "LRS"		# TODO - Change to RAGRS for production

  access_tier               = "Cool"			

  enable_https_traffic_only = true
  min_tls_version           = "TLS1_2"
  allow_blob_public_access  = false
}

resource "azurerm_storage_container" "appsvclogs" {
  name                      = "appsvclogs"
  storage_account_name      = azurerm_storage_account.logs.name
  container_access_type     = "private"
}

resource "azurerm_log_analytics_workspace" "main" {
  name                      = "log-${var.product_name}-${var.environment}-${var.location}-001"
  location                  = var.location
  resource_group_name       = var.resource_group_name
  sku                       = "PerGB2018"
  retention_in_days         = 30 		# min 30, max 730
}


