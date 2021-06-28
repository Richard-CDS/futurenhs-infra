variable location { type = string }

variable environment { type = string }

variable product_name { type = string }

variable resource_group_name { type = string }

variable log_storage_account_blob_endpoint { 
  type            = string 
  #sensitive       = true
}

variable log_storage_account_access_key { 
  type            = string
  #sensitive       = true
}

variable key_vault_id { type = string }

variable sqlserver_admin_email {
  type = string
  #sensitive = true
}