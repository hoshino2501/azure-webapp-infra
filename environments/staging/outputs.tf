output "resource_group_name" {
  description = "リソースグループ名"
  value       = azurerm_resource_group.this.name
}

output "app_service_url" {
  description = "App Service のデフォルト URL"
  value       = "https://${module.app_service.app_service_default_hostname}"
}

output "postgresql_fqdn" {
  description = "PostgreSQL サーバーの FQDN"
  value       = module.postgresql.server_fqdn
}

output "key_vault_uri" {
  description = "Key Vault の URI"
  value       = module.key_vault.key_vault_uri
}

output "log_analytics_workspace_id" {
  description = "Log Analytics Workspace の ID"
  value       = module.log_analytics.workspace_id
}

output "entra_client_id" {
  description = "Entra アプリケーションのクライアント ID"
  value       = module.entra_external_id.client_id
}
