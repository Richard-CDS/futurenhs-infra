variable product_name { type = string }
variable environment { type = string }
variable location { type = string }

variable resource_group_name { type = string }

variable forum_sql_database_name { type = string }

variable forum_database_connection_string { 
  type      = string
  sensitive = true
}