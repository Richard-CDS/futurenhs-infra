data "azurerm_storage_account_blob_container_sas" "forum_logs" {
  connection_string                         = var.log_storage_account_connection_string
  container_name                            = var.log_storage_account_container_name
  https_only                                = true

  start                                     = timestamp()
  expiry                                    = timeadd(timestamp(), "876000h")	# 100 years - TODO - confused why we have to use a SAS token for this given it expires.  Don't do this in the portal.

  permissions {
    read                                    = true
    add                                     = true
    create                                  = true
    write                                   = true
    delete                                  = true
    list                                    = true
  }
}

resource "azurerm_app_service_plan" "forum" {
  name                                      = "plan-${lower(var.product_name)}-${lower(var.environment)}-${lower(var.location)}-forum"
  location                                  = var.location
  resource_group_name                       = var.resource_group_name
  kind                                      = "Windows"
  per_site_scaling                          = true
  reserved                                  = false  

  sku {
    tier                                    = "Standard"	# needed for deployment slots and auto-scaling
    size                                    = "P1V2"      # "S1"
    capacity                                = 1
  }

  lifecycle {
    ignore_changes = [
      tags
    ]
  }
}

data "azurerm_monitor_diagnostic_categories" "plan" {
  resource_id                                  = azurerm_app_service_plan.forum.id
}

resource "azurerm_monitor_diagnostic_setting" "plan" {
  name                                         = "plan-forum-diagnostics"
  target_resource_id                           = azurerm_app_service_plan.forum.id
  log_analytics_workspace_id                   = var.log_analytics_workspace_resource_id
  storage_account_id                           = var.log_storage_account_id

  dynamic "log" {
    iterator = log_category
    for_each = data.azurerm_monitor_diagnostic_categories.plan.logs

    content {
      category = log_category.value
      enabled  = true

      retention_policy {
        enabled = true
        days    = 7        # TODO - Increase for production or set to 0 for infinite retention
      }
    }
  }

  dynamic "metric" {
    iterator = metric_category
    for_each = data.azurerm_monitor_diagnostic_categories.plan.metrics

    content {
      category = metric_category.value
      enabled  = true

      retention_policy {
        enabled = true
        days    = 7        # TODO - Increase for production or set to 0 for infinite retention
      }
    }
  }
}


resource "azurerm_app_service" "forum" {
  name                                      = "app-${lower(var.product_name)}-${lower(var.environment)}-${lower(var.location)}-forum"
  location                                  = var.location
  resource_group_name                       = var.resource_group_name
  app_service_plan_id                       = azurerm_app_service_plan.forum.id

  enabled                                   = true
  client_affinity_enabled                   = false
  client_cert_enabled                       = false
  https_only                                = true
  
  identity {
    type                                    = "SystemAssigned"
  }

  site_config {
    always_on                               = true
    dotnet_framework_version                = "v4.0"
    remote_debugging_enabled                = false
    remote_debugging_version                = "VS2019"
    ftps_state                              = "Disabled"
    health_check_path                       = "api/HealthCheck/heartbeat"
    http2_enabled                           = false
    ip_restriction                          = [] # [ { name = "ipr-" priority = "65000" action = "Allow" ip_address = "" | service_tag = "" | virtual_network_subnet_id = "" } ]
    scm_use_main_ip_restriction             = true
    scm_ip_restriction                      = []
    local_mysql_enabled                     = false
    managed_pipeline_mode                   = "Integrated"
    min_tls_version                         = "1.2"
    scm_type                                = "None"
    use_32_bit_worker_process               = false
    websockets_enabled                      = false
  }

  app_settings = {
    "APPINSIGHTS_INSTRUMENTATIONKEY"        = var.forum_app_insights_instrumentation_key
    "APPLICATIONINSIGHTS_CONNECTION_STRING" = var.forum_app_insights_connection_string
    "APPINSIGHTS_PROFILERFEATURE_VERSION"   = "1.0.0"
    "DiagnosticServices_EXTENSION_VERSION"  = "~3"
    "ASPNET_ENV"                            = var.environment                                   # this value will be used to match with the label on the environment specific configuration in the azure app config service
    "ASPNETCORE_ENVIRONMENT"                = var.environment                                   # this value will be used to match with the label on the environment specific configuration in the azure app config service
    
    "AzureAppConfiguration:PrimaryEndpoint" = var.forum_app_config_primary_endpoint		          # to get app config for the environment including feature flags

    # Added to try and simulate what portal does to configure app insights .NET coverage on app server
    # Removed again to see if they are the cause for a lack of telemetry being collected/visible for service (could be hidden settings we're missing?)

    #"APPINSIGHTS_SNAPSHOTFEATURE_VERSION"   = "1.0.0"
    #"ApplicationInsightsAgent_EXTENSION_VERSION" = "~2" 
    #"InstrumentationEngine_EXTENSION_VERSION" = "disabled" 
    #"SnapshotDebugger_EXTENSION_VERSION" = "disabled" 
    #"XDT_MicrosoftApplicationInsights_BaseExtensions" = "~1" 
    #"XDT_MicrosoftApplicationInsights_Java" = "1" 
    #"XDT_MicrosoftApplicationInsights_Mode" = "recommended" 
    #"XDT_MicrosoftApplicationInsights_NodeJs" = "recommended" 
    #"XDT_MicrosoftApplicationInsights_PreemptSdk" = "disabled" 

    # TODO - Move the following settings to the azure config service for the forum once it has been integrated with the site

    "AzureBlobStorage:PrimaryEndpoint"      = var.forum_primary_blob_container_endpoint		# for storing avatar and group images
    "BlobContainer"                         = var.forum_primary_blob_container_name
    "StorageProvider"                       = "MvcForum.Plugins.Providers.AzureBlobStorageProvider"
  }

  connection_string {
    name                                    = "MVCForumContext"
    type                                    = "SQLAzure"
    value                                   = var.forum_db_keyvault_connection_string_reference
  }

  # Add connection string for read scale-out support (available in Premium/Business Critical editions of Azure SQL by default) .. ApplicationIntent=ReadOnly
  connection_string {
    name                                    = "Forum_ReadOnlyIntent"
    type                                    = "SQLAzure"
    value                                   = var.forum_db_keyvault_connection_string_reference
  }

  connection_string {
    name                                    = "AzureBlobStorage:PrimaryConnectionString"
    type                                    = "Custom"
    value                                   = var.forum_primary_blob_keyvault_connection_string_reference
  }

  connection_string {
    name                                    = "AzureAppConfiguration:PrimaryConnectionString"
    type                                    = "Custom"
    value                                   = var.forum_app_config_primary_keyvault_connection_string_reference
  }

  logs {
    detailed_error_messages_enabled         = true
    failed_request_tracing_enabled          = true

    application_logs {
      #file_system_level                     = "Error"

      azure_blob_storage { 
        level                               = "Information"	# Off | Error | Verbose | Information | Warning
        sas_url                             = "${var.log_storage_account_blob_endpoint}${var.log_storage_account_container_name}${data.azurerm_storage_account_blob_container_sas.forum_logs.sas}"
        retention_in_days                   = 7			# TODO - Extend for production
      }
    }

    http_logs {
      azure_blob_storage { 
        sas_url                             = "${var.log_storage_account_blob_endpoint}${var.log_storage_account_container_name}${data.azurerm_storage_account_blob_container_sas.forum_logs.sas}"
        retention_in_days                   = 7			# TODO - Extend for production
      }
      #file_system {
      #  retention_in_days                   = 7
      #  retention_in_mb                     = 35
      #}
    }
  }

  lifecycle {
    ignore_changes = [
      tags
    ]
  }
}

# TODO - Comment back in once the terraform state file has been fixed by importing these resources

# assign the blob reader role to the system identity so it can access the public blob storage container used by the forum to save images etc
# using its managed identity rather than having to manage connection string and sas tokens etc

#resource "azurerm_role_assignment" "forum_blob_reader" {
#  scope                                     = var.forum_primary_blob_container_resource_manager_id
#  principal_id                              = azurerm_app_service.forum.identity[0].principal_id
#  role_definition_name                      = "Storage Blob Data Contributor"
#}

data "azurerm_monitor_diagnostic_categories" "main" {
  resource_id                                  = azurerm_app_service.forum.id
}

resource "azurerm_monitor_diagnostic_setting" "main" {
  name                                         = "app-forum-diagnostics"
  target_resource_id                           = azurerm_app_service.forum.id
  log_analytics_workspace_id                   = var.log_analytics_workspace_resource_id
  storage_account_id                           = var.log_storage_account_id

  dynamic "log" {
    iterator = log_category
    for_each = data.azurerm_monitor_diagnostic_categories.main.logs

    content {
      category = log_category.value
      enabled  = true

      retention_policy {
        enabled = true
        days    = 7        # TODO - Increase for production or set to 0 for infinite retention
      }
    }
  }

  dynamic "metric" {
    iterator = metric_category
    for_each = data.azurerm_monitor_diagnostic_categories.main.metrics

    content {
      category = metric_category.value
      enabled  = true

      retention_policy {
        enabled = true
        days    = 7        # TODO - Increase for production or set to 0 for infinite retention
      }
    }
  }
}



# for some unknown reason terraform crashes when we try to manage the slot
# decided for now i'm going to handle this in the deployment pipeline using the azure cli
# once terraform has been fixed or someone can figure out what is wrong then we can come back to using this

#resource "azurerm_app_service_slot" "forum" {
#  name                              = "staging"  # combined with app_service_name must be less than 59 characters
#  location                          = var.location
#  resource_group_name               = var.resource_group_name
#  app_service_plan_id               = azurerm_app_service_plan.forum.id
#  app_service_name                  = azurerm_app_service.forum.name
#
#  # the following bits are to be the same as the main app service unless we decide on sticky config or to use different dbs for staging etc
#  # note there are a few fields not supported by the slot:
#  # client_cert_enabled
#
#  enabled                           = true
#  client_affinity_enabled           = false
#  https_only                        = false
#  
# identity {
#   type                            = "SystemAssigned"
# }
#
#  site_config {
#    dotnet_framework_version        = "v4.0"
#    remote_debugging_enabled        = true
#    remote_debugging_version        = "VS2019"
#    ftps_state                      = "Disabled"
#    health_check_path               = "health-check"
#    http2_enabled                   = false
#    ip_restriction                  = [] # [ { name = "ipr-" priority = "65000" action = "Allow" ip_address = "" | service_tag = "" | virtual_network_subnet_id = "" } ]
#    scm_use_main_ip_restriction     = true
#    scm_ip_restriction              = []
#    local_mysql_enabled             = false
#    managed_pipeline_mode           = "Integrated"
#    min_tls_version                 = 1.2
#    scm_type                        = "None"
#    use_32_bit_worker_process       = false
#    websockets_enabled              = false
#  }
#
#  app_settings = {
#    "EXAMPLE_KEY" = "an-example-value"
#  }
#
#  connection_string {
#    name  = "MVCForumContext"
#    type  = "SQLAzure"
#    value = var.forum_keyvault_connection_string_reference
#  }
#
#  logs {
#    detailed_error_messages_enabled = true
#    failed_request_tracing_enabled  = true
#
#    application_logs {
#      azure_blob_storage { 
#        level                       = "Information"
#        sas_url                     = var.log_storage_account_sas_url
#        retention_in_days           = 7
#      }
#    }
#
#    http_logs {
#      azure_blob_storage { 
#        sas_url                     = var.log_storage_account_sas_url
#        retention_in_days           = 7
#      }
#    }
#  }
#}