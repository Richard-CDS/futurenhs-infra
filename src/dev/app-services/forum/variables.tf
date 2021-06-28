variable location { type = string }

variable environment { type = string }

variable product_name { type = string }

variable resource_group_name { type = string }

variable log_storage_account_connection_string { 
  type = string
  sensitive = true
} 

variable log_storage_account_blob_endpoint { type = string }

variable log_storage_account_container_name { type = string }

variable forum_keyvault_connection_string_reference { type = string }

variable forum_app_config_primary_endpoint { type = string }

variable forum_primary_blob_container_endpoint { type = string }

variable forum_primary_blob_container_resource_manager_id { type = string }

variable forum_app_insights_instrumentation_key { 
  type      = string 
  sensitive = true
}

variable forum_app_insights_connection_string { 
  type      = string
  sensitive = true
}