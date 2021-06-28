# storage account used to house publically accessible artefacts such as images used for groups in the forum.  A CDN may be put in front of this

resource "azurerm_storage_account" "public_content" {
  name                       = "sa${var.product_name}${var.environment}${var.location}pub"
  resource_group_name        = var.resource_group_name
  location                   = var.location

  account_tier               = "Standard"	# TODO - Change to Premium for production
  account_kind               = "BlobStorage"    # TODO - "BlockBlobStorage" require Premium account_tier (see above)
  account_replication_type   = "LRS"		# TODO - Change to RAGRS for production

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
      days                   = 7  # TODO - Change for production : 1 through 365      
    }

    # TODO - put this back in once the container soft delete is out of preview (https://docs.microsoft.com/en-us/azure/storage/blobs/soft-delete-container-overview?tabs=powershell#register-for-the-preview)
    #container_delete_retention_policy {
    #  days                   = 7  # TODO - Change for production : 1 through 365            
    #}
  }
}

resource "azurerm_storage_container" "forum" {
  name                       = "forum"
  storage_account_name       = azurerm_storage_account.public_content.name
  container_access_type      = "blob"	# blob | container | private
}