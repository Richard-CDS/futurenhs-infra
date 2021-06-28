resource "azurerm_network_watcher_flow_log" "default" {
  network_watcher_name                           = var.network_watcher_name
  resource_group_name                            = azurerm_network_security_group.default.resource_group_name

  network_security_group_id                      = azurerm_network_security_group.default.id
  storage_account_id                             = var.log_storage_account_id
  enabled                                        = true
  version                                        = 2

  retention_policy {
    enabled                                      = true
    days                                         = 7
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
}

resource "azurerm_public_ip" "default" {
  name                                           = "pip-${lower(var.product_name)}-${lower(var.environment)}-${lower(var.location)}-default"
  resource_group_name                            = var.resource_group_name
  location                                       = var.location
  sku                                            = "Standard"
  allocation_method                              = "Static"
  domain_name_label                              = "${lower(var.product_name)}-${lower(var.environment)}"
}

resource "azurerm_network_security_group" "default" {
  name                                           = "nsg-${lower(var.product_name)}-${lower(var.environment)}-${lower(var.location)}-default"
  location                                       = var.location
  resource_group_name                            = var.resource_group_name
}

resource "azurerm_application_gateway" "default" {
  name                                           = "agw-${lower(var.product_name)}-${lower(var.environment)}-${lower(var.location)}-default"
  resource_group_name                            = var.resource_group_name
  location                                       = var.location
  zones                                          = ["1","2","3"]
  enable_http2                                   = false  

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
    ssl_certificate_name                         = var.forum_app_key_vault_certificate_name
  }

  ssl_certificate {
    name                                         = var.forum_app_key_vault_certificate_name
    key_vault_secret_id                          = var.forum_app_key_vault_certificate_secret_id
  }

  backend_http_settings {
    name                                         = "agw-forum-backend-https"
    cookie_based_affinity                        = "Disabled"
    #path                                         = "/"
    host_name                                    = "futurenhs.cds.co.uk"
    port                                         = 443
    protocol                                     = "Https"
    request_timeout                              = 60
  }

  backend_address_pool {
    name                                         = "agw-forum-backend-address-pool"
    fqdns                                        = [
      "app-${lower(var.product_name)}-${lower(var.environment)}-${lower(var.location)}-forum.azurewebsites.net"
    ]
  }
}