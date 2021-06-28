module "forum" {
  source                                            = "./forum"

  resource_group_name                               = var.resource_group_name

  location                                          = var.location
  environment                                       = var.environment
  product_name                                      = var.product_name

  log_storage_account_connection_string             = var.log_storage_account_connection_string
  log_storage_account_blob_endpoint                 = var.log_storage_account_blob_endpoint
  log_storage_account_container_name                = var.log_storage_account_container_name

  forum_app_config_primary_endpoint                 = var.forum_app_config_primary_endpoint

  forum_primary_blob_container_endpoint             = var.forum_primary_blob_container_endpoint
  forum_primary_blob_container_resource_manager_id  = var.forum_primary_blob_container_resource_manager_id

  forum_app_insights_instrumentation_key            = var.forum_app_insights_instrumentation_key
  forum_app_insights_connection_string              = var.forum_app_insights_connection_string

  forum_keyvault_connection_string_reference        = var.forum_keyvault_connection_string_reference
}