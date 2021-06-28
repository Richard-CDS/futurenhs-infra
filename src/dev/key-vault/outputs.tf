output "key_vault_id" {
  value = azurerm_key_vault.main.id
}

output key_vault_certificate_secret_id_forum_https {
  value = azurerm_key_vault_certificate.app_forum_https.secret_id
}

output key_vault_certificate_name_forum_https {
  value = azurerm_key_vault_certificate.app_forum_https.name
}