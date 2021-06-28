resource "random_password" "sqlserver_admin_user" {
  length                                        = 20
  special                                       = true
}

resource "azurerm_key_vault_secret" "sqlserver_admin_user" {
  name                                          = "${lower(var.product_name)}-${lower(var.environment)}-${lower(var.location)}-sqlserver-adminuser"
  value                                         = random_password.sqlserver_admin_user.result
  key_vault_id                                  = var.key_vault_id

  lifecycle {
    ignore_changes = [
      value
    ]
  }
}

resource "random_password" "sqlserver_admin_pwd" {
  length                                        = 20
  special                                       = true
  min_lower                                     = 1
  min_upper                                     = 1
  min_special                                   = 1
  min_numeric                                   = 1
}
	
resource "azurerm_key_vault_secret" "sqlserver_admin_pwd" {
  name                                          = "${lower(var.product_name)}-${lower(var.environment)}-${lower(var.location)}-sqlserver-adminpwd"
  value                                         = random_password.sqlserver_admin_pwd.result
  key_vault_id                                  = var.key_vault_id

  lifecycle {
    ignore_changes = [
      value
    ]
  }
}


# All Azure SQL databases are automatically backed up to RA-GRS by the server.

resource "azurerm_mssql_server" "primary" {
  name                                          = "sql-${lower(var.product_name)}-${lower(var.environment)}-${lower(var.location)}-primary"
  resource_group_name                           = var.resource_group_name
  location                                      = var.location
  version                                       = "12.0"
  connection_policy                             = "Default"
  administrator_login                           = azurerm_key_vault_secret.sqlserver_admin_user.value
  administrator_login_password                  = azurerm_key_vault_secret.sqlserver_admin_pwd.value
  minimum_tls_version                           = "1.2"

  public_network_access_enabled                 = true # TODO - Remove this for production configuration and lock down with firewall rules etc

  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_mssql_server_extended_auditing_policy" "primary" {
  server_id                                     = azurerm_mssql_server.primary.id
  storage_endpoint                              = var.log_storage_account_blob_endpoint
  storage_account_access_key                    = var.log_storage_account_access_key
  storage_account_access_key_is_secondary       = false
  retention_in_days                             = 7
  log_monitoring_enabled                        = true
}

# https://docs.microsoft.com/en-us/rest/api/sql/firewallrules/createorupdate
resource "azurerm_mssql_firewall_rule" "firewall_rule_1" {
  name                                         = "sqlfwr-${var.product_name}-${var.environment}-${var.location}-001"
  server_id                                    = azurerm_mssql_server.primary.id
  start_ip_address                             = "0.0.0.0"
  end_ip_address                               = "0.0.0.0"
}


# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/mssql_elasticpool
resource "azurerm_mssql_elasticpool" "primary" {
  name                                          = "sqlep-${var.product_name}-${var.environment}-${var.location}-primary"
  resource_group_name                           = var.resource_group_name
  location                                      = var.location
  server_name                                   = azurerm_mssql_server.primary.name
  license_type                                  = "LicenseIncluded" # LicenseIncluded | BasePrice
  max_size_gb                                   = 4.8828125		# 756
  zone_redundant                                = false	

  sku {
    name                                        = "BasicPool" 	# "GP_Gen5"
    tier                                        = "Basic" 		#"GeneralPurpose"
    #family                                      = "Gen5"
    capacity                                    = 50		#4 
  }

  per_database_settings {
    min_capacity                                = 5			# 0.25
    max_capacity                                = 5			# 4
  }

  lifecycle {
    ignore_changes = [
      license_type
    ]
  }
}



module "forum" {
  source = "./forum"

  resource_group_name                            = var.resource_group_name

  location                                       = var.location
  environment                                    = var.environment
  product_name                                   = var.product_name

  key_vault_id                                   = var.key_vault_id

  log_storage_account_blob_endpoint              = var.log_storage_account_blob_endpoint
  log_storage_account_access_key                 = var.log_storage_account_access_key

  sql_server_id                                  = azurerm_mssql_server.primary.id
  sql_server_elasticpool_id                      = azurerm_mssql_elasticpool.primary.id
  sqlserver_admin_email                          = var.sqlserver_admin_email

  sql_server_primary_fully_qualified_domain_name = azurerm_mssql_server.primary.fully_qualified_domain_name

  # TODO - Change below to use none admin credentials when forum up and running and access rights are understood.  Using admin credentials is no good!

  database_login_user                            = azurerm_mssql_server.primary.administrator_login
  database_login_password                        = azurerm_mssql_server.primary.administrator_login_password
}

