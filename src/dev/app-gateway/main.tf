resource "azurerm_network_watcher_flow_log" "default" {
  network_watcher_name                           = var.network_watcher_name
  resource_group_name                            = azurerm_network_security_group.default.resource_group_name

  network_security_group_id                      = azurerm_network_security_group.default.id
  storage_account_id                             = var.log_storage_account_id
  enabled                                        = true
  version                                        = 2

  retention_policy {
    enabled                                      = true
    days                                         = 120
  }
 
  traffic_analytics {
    enabled                                      = true
    workspace_id                                 = var.log_analytics_workspace_id
    workspace_region                             = var.location
    workspace_resource_id                        = var.log_analytics_workspace_resource_id
    interval_in_minutes                          = 10
  }
}

resource "azurerm_subnet" "default" {
  name                                           = "snet-${lower(var.product_name)}-${lower(var.environment)}-${lower(var.location)}-default"
  resource_group_name                            = azurerm_network_security_group.default.resource_group_name
  virtual_network_name                           = var.virtual_network_name
  address_prefixes                               = ["10.0.1.0/24"]

  enforce_private_link_endpoint_network_policies = false
  enforce_private_link_service_network_policies  = false

  service_endpoints                              = [
    "Microsoft.KeyVault",
    "Microsoft.Sql", 
    "Microsoft.Storage",
    "Microsoft.Web"
  ]
}

resource "azurerm_public_ip" "default" {
  name                                           = "pip-${lower(var.product_name)}-${lower(var.environment)}-${lower(var.location)}-default"
  resource_group_name                            = var.resource_group_name
  location                                       = var.location
  sku                                            = "Standard"
  allocation_method                              = "Static"
  domain_name_label                              = "${lower(var.product_name)}-${lower(var.environment)}"
}

data "azurerm_monitor_diagnostic_categories" "pip" {
  resource_id                                  = azurerm_public_ip.default.id
}

resource "azurerm_monitor_diagnostic_setting" "pip" {
  name                                         = "pip-diagnostics"
  target_resource_id                           = azurerm_public_ip.default.id
  log_analytics_workspace_id                   = var.log_analytics_workspace_resource_id
  storage_account_id                           = var.log_storage_account_id

  dynamic "log" {
    iterator = log_category
    for_each = data.azurerm_monitor_diagnostic_categories.pip.logs

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
    for_each = data.azurerm_monitor_diagnostic_categories.pip.metrics

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

resource "azurerm_network_security_group" "default" {
  name                                           = "nsg-${lower(var.product_name)}-${lower(var.environment)}-${lower(var.location)}-default"
  location                                       = var.location
  resource_group_name                            = var.resource_group_name
}

# We need a security rule to allow the Application Gateway to communicate 
# https://docs.microsoft.com/en-us/azure/application-gateway/configuration-infrastructure#network-security-groups

resource "azurerm_network_security_rule" "allow_gateway_manager_inbound" {
  name                                           = "AllowGatewayManagerInbound"
  description                                    = "Authorise App Gateway Manager"
  priority                                       = 100 # 100 - 4096
  direction                                      = "Inbound" # Inbound | Outbound
  access                                         = "Allow" # Allow | Deny
  protocol                                       = "Tcp" # Tcp | Udp | Icmp | Esp | Ah | *
  source_port_range                              = "*"
  destination_port_range                         = "65200-65535"
  source_address_prefix                          = "GatewayManager"
  destination_address_prefix                     = "*"
  resource_group_name                            = var.resource_group_name
  network_security_group_name                    = azurerm_network_security_group.default.name
}

# Open up access to public over http/s

resource "azurerm_network_security_rule" "allow_public_http_inbound" {
  name                                           = "AllowPublicHttpInbound"
  description                                    = "Authorise Https(s) requests from the internet to access the web application"
  priority                                       = 101 
  direction                                      = "Inbound" 
  access                                         = "Allow" 
  protocol                                       = "Tcp" 
  source_port_range                              = "*"
  destination_port_ranges                        = [ "80", "443" ]
  source_address_prefix                          = "*"
  destination_address_prefix                     = "*"
  resource_group_name                            = var.resource_group_name
  network_security_group_name                    = azurerm_network_security_group.default.name
}

data "azurerm_monitor_diagnostic_categories" "nsg" {
  resource_id                                  = azurerm_network_security_group.default.id
}

resource "azurerm_monitor_diagnostic_setting" "nsg" {
  name                                         = "nsg-diagnostics"
  target_resource_id                           = azurerm_network_security_group.default.id
  log_analytics_workspace_id                   = var.log_analytics_workspace_resource_id
  storage_account_id                           = var.log_storage_account_id

  dynamic "log" {
    iterator = log_category
    for_each = data.azurerm_monitor_diagnostic_categories.nsg.logs

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
    for_each = data.azurerm_monitor_diagnostic_categories.nsg.metrics

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

resource "azurerm_subnet_network_security_group_association" "default_subnet" {
  subnet_id                                      = azurerm_subnet.default.id
  network_security_group_id                      = azurerm_network_security_group.default.id

  depends_on = [ 
    azurerm_network_security_rule.allow_gateway_manager_inbound  
  ]
}

resource "azurerm_application_gateway" "default" {
  name                                           = "agw-${lower(var.product_name)}-${lower(var.environment)}-${lower(var.location)}-default"
  resource_group_name                            = var.resource_group_name
  location                                       = var.location
  zones                                          = ["1","2","3"]
  enable_http2                                   = true  

  sku {
    name     = "WAF_v2"
    tier     = "WAF_v2"
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [var.managed_identity_app_gateway]
  }

  autoscale_configuration {
    min_capacity                                 = 1   # min = 1, max = 100
    max_capacity                                 = 2   # min = 2, max = 125
  }

  waf_configuration {
    enabled                                      = true
    firewall_mode                                = "Detection" # Detection | Prevention
    rule_set_type                                = "OWASP"
    rule_set_version                             = "3.1"
    file_upload_limit_mb                         = 750
    request_body_check                           = true
    max_request_body_size_kb                     = 128    
  }

  gateway_ip_configuration {
    name                                         = "agw-ipconfig"
    subnet_id                                    = azurerm_subnet.default.id
  }

  frontend_port {
    name                                         = "agw-frontend-port-443"
    port                                         = 443
  }

  frontend_port {
    name                                         = "agw-frontend-port-80"
    port                                         = 80
  }

  frontend_ip_configuration {
    name                                         = "agw-frontend-ipconfig-public"
    public_ip_address_id                         = azurerm_public_ip.default.id
  }

  http_listener {
    name                                         = "agw-http-listener"
    frontend_ip_configuration_name               = "agw-frontend-ipconfig-public"
    frontend_port_name                           = "agw-frontend-port-80"
    protocol                                     = "Http"
  }



  # Rules to route requests for the forum web application to the appropriate hosted app service

  redirect_configuration {
    name                                         = "agw-forum-redirecting-http-to-https"
    redirect_type                                = "Permanent"
    include_path                                 = true
    include_query_string                         = true
    target_listener_name                         = "agw-forum-https-listener"
  }

  request_routing_rule {
    name                                         = "agw-forum-routing-http"
    rule_type                                    = "Basic"
    http_listener_name                           = "agw-http-listener"
    redirect_configuration_name                  = "agw-forum-redirecting-http-to-https"
  }

  request_routing_rule {
    name                                         = "agw-forum-routing-https"
    rule_type                                    = "Basic"
    http_listener_name                           = "agw-forum-https-listener"
    backend_address_pool_name                    = "agw-forum-backend-address-pool"
    backend_http_settings_name                   = "agw-forum-backend-https"
  }

  http_listener {
    name                                         = "agw-forum-https-listener"
    frontend_ip_configuration_name               = "agw-frontend-ipconfig-public"
    frontend_port_name                           = "agw-frontend-port-443"
    protocol                                     = "Https"
    ssl_certificate_name                         = var.key_vault_certificate_https_name
  }

  ssl_certificate {
    name                                         = var.key_vault_certificate_https_name
    key_vault_secret_id                          = var.key_vault_certificate_https_versionless_secret_id
  }

  backend_http_settings {
    name                                         = "agw-forum-backend-https"
    cookie_based_affinity                        = "Disabled"
    #affinity_cookie_name                         = ""
    #path                                         = "/"
    port                                         = 443
    protocol                                     = "Https"
    request_timeout                              = 60
    probe_name                                   = "agw-forum-probe"
    #host_name                                    = "futurenhs.cds.co.uk" 
    pick_host_name_from_backend_address          = true
  }

  probe {
    name                                         = "agw-forum-probe"
    interval                                     = 30 # 1 - 86400
    protocol                                     = "Https"
    path                                         = "/api/HealthCheck/heartbeat"
    timeout                                      = 30 # 1 - 86400
    unhealthy_threshold                          = 3 # 1 - 20
    #port                                         = "443"
    pick_host_name_from_backend_http_settings    = true
    minimum_servers                              = 0
  }

  backend_address_pool {
    name                                         = "agw-forum-backend-address-pool"
    fqdns                                        = [
      "app-${lower(var.product_name)}-${lower(var.environment)}-${lower(var.location)}-forum.azurewebsites.net"
    ]
  }
}

data "azurerm_monitor_diagnostic_categories" "agw_waf" {
  resource_id                                  = azurerm_application_gateway.default.id
}

resource "azurerm_monitor_diagnostic_setting" "agw-waf" {
  name                                         = "agw-waf-diagnostics"
  target_resource_id                           = azurerm_application_gateway.default.id
  log_analytics_workspace_id                   = var.log_analytics_workspace_resource_id
  storage_account_id                           = var.log_storage_account_id

  dynamic "log" {
    iterator = log_category
    for_each = data.azurerm_monitor_diagnostic_categories.agw_waf.logs

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
    for_each = data.azurerm_monitor_diagnostic_categories.agw_waf.metrics

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
