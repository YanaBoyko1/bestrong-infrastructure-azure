output "web_app_url" {
  description = "Публічна URL-адреса Web App (для відкриття в браузері)"
  value       = "https://${azurerm_linux_web_app.web_app.default_hostname}"
}

output "acr_login_server" {
  description = "Адреса ACR для docker push/pull у CI/CD пайплайні"
  value       = azurerm_container_registry.acr.login_server
}

output "sql_server_fqdn" {
  description = "Повна доменна адреса SQL Server для рядка підключення"
  value       = azurerm_mssql_server.sql_server.fully_qualified_domain_name
}

output "storage_account_name" {
  description = "Назва Storage Account"
  value       = azurerm_storage_account.storage.name
}

output "storage_share_name" {
  description = "Назва File Share всередині Storage Account"
  value       = azurerm_storage_share.user_files.name
}

output "key_vault_uri" {
  description = "URI Key Vault для ручного читання секретів через CLI"
  value       = azurerm_key_vault.kv.vault_uri
}

output "key_vault_id" {
  description = "ID Key Vault (для додавання нових access policy)"
  value       = azurerm_key_vault.kv.id
}
