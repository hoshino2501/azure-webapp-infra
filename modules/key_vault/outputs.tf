output "key_vault_id" {
  description = "Key Vault の ID"
  value       = azurerm_key_vault.this.id
}

output "key_vault_name" {
  description = "Key Vault の名前"
  value       = azurerm_key_vault.this.name
}

output "key_vault_uri" {
  description = "Key Vault の URI"
  value       = azurerm_key_vault.this.vault_uri
}

output "db_password_secret_id" {
  description = "DB パスワードシークレットの ID"
  value       = azurerm_key_vault_secret.db_password.id
}
