# storage account used to house publically accessible artefacts such as images used for groups in the forum.  A CDN may be put in front of this

resource "azurerm_storage_account" "public_content" {
  name                       = "sa${var.product_name}${var.environment}${var.location}pub"
  resource_group_name        = var.resource_group_name
  location                   = var.location

  account_tier               = "Standard"	
  account_kind               = "StorageV2"    
  account_replication_type   = "RAGRS"		  # TODO - For Production, change to RAGZRS

  access_tier                = "Hot"			

  enable_https_traffic_only  = true
  min_tls_version            = "TLS1_2"
  allow_blob_public_access   = true

  identity {
    type                     = "SystemAssigned"
  }

  blob_properties {
    versioning_enabled       = true
    change_feed_enabled      = false
    last_access_time_enabled = false

    # add the soft-delete policies to the storage account

    delete_retention_policy {
      days                   = 90  # 1 through 365      
    }

    # TODO - put this back in once the container soft delete is out of preview (https://docs.microsoft.com/en-us/azure/storage/blobs/soft-delete-container-overview?tabs=powershell#register-for-the-preview)
    #container_delete_retention_policy {
    #  days                   = 90  # 1 through 365            
    #}
  }
}

resource "azurerm_storage_container" "forum" {
  name                       = "forum"
  storage_account_name       = azurerm_storage_account.public_content.name
  container_access_type      = "blob"	# blob | container | private
}

resource "azurerm_key_vault_secret" "blobs_primary_forum_connection_string" {
  name                                      = "blobs-${var.product_name}-${var.environment}-${var.location}-forum-connection-string"
  value                                     = azurerm_storage_account.public_content.primary_connection_string
  key_vault_id                              = var.key_vault_id

  content_type                              = "text/plain"
  expiration_date                           = timeadd(timestamp(), "87600h")   
}

data "azurerm_monitor_diagnostic_categories" "storage_category" {
  resource_id                                  = azurerm_storage_account.public_content.id
}

resource "azurerm_monitor_diagnostic_setting" "storage" {
  name                                         = "public-storage-account-diagnostics"
  target_resource_id                           = azurerm_storage_account.public_content.id
  log_analytics_workspace_id                   = var.log_analytics_workspace_resource_id
  storage_account_id                           = var.log_storage_account_id

  dynamic "log" {
    iterator = log_category
    for_each = data.azurerm_monitor_diagnostic_categories.storage_category.logs

    content {
      category = log_category.value
      enabled  = true

      retention_policy {
        enabled = true
        days    = 90
      }
    }
  }

  dynamic "metric" {
    iterator = metric_category
    for_each = data.azurerm_monitor_diagnostic_categories.storage_category.metrics

    content {
      category = metric_category.value
      enabled  = true

      retention_policy {
        enabled = true
        days    = 90
      }
    }
  }
}

data "azurerm_monitor_diagnostic_categories" "storage_blob_category" {
  resource_id                                  = "${azurerm_storage_account.public_content.id}/blobServices/default/"
}

resource "azurerm_monitor_diagnostic_setting" "blob" {
  ## https://github.com/terraform-providers/terraform-provider-azurerm/issues/8275
  name                                         = "log-storage-account-blob-diagnostics"
  target_resource_id                           = "${azurerm_storage_account.public_content.id}/blobServices/default/"
  log_analytics_workspace_id                   = var.log_analytics_workspace_resource_id
  storage_account_id                           = var.log_storage_account_id

  dynamic "log" {
    iterator = log_category
    for_each = data.azurerm_monitor_diagnostic_categories.storage_blob_category.logs

    content {
      category = log_category.value
      enabled  = true

      retention_policy {
        enabled = true
        days    = 90
      }
    }
  }

  dynamic "metric" {
    iterator = metric_category
    for_each = data.azurerm_monitor_diagnostic_categories.storage_blob_category.metrics

    content {
      category = metric_category.value
      enabled  = true

      retention_policy {
        enabled = true
        days    = 90
      }
    }
  }
}