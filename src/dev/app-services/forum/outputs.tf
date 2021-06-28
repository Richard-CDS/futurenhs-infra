output app_service_name {
  value = azurerm_app_service.forum.name
}

output app_service_default_hostname {
  value = "https://${azurerm_app_service.forum.default_site_hostname}"
}

output app_service_fqdn {
  value = azurerm_app_service.forum.default_site_hostname
}

output principal_id {
  value = azurerm_app_service.forum.identity[0].principal_id
}