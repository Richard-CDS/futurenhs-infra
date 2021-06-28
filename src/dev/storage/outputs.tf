output forum_primary_blob_container_endpoint {
  value = "${azurerm_storage_account.public_content.primary_blob_endpoint}${azurerm_storage_container.forum.name}"
}

output forum_primary_blob_container_resource_manager_id {
  value = azurerm_storage_container.forum.resource_manager_id
}

output forum_primary_blob_container_name {
  value = azurerm_storage_container.forum.name
}
