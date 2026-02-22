output "server_id" {
  description = "PostgreSQL フレキシブルサーバーの ID"
  value       = azurerm_postgresql_flexible_server.this.id
}

output "server_name" {
  description = "PostgreSQL フレキシブルサーバーの名前"
  value       = azurerm_postgresql_flexible_server.this.name
}

output "server_fqdn" {
  description = "PostgreSQL フレキシブルサーバーの FQDN"
  value       = azurerm_postgresql_flexible_server.this.fqdn
}

output "database_name" {
  description = "作成したデータベース名"
  value       = azurerm_postgresql_flexible_server_database.app.name
}
