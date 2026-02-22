resource "azurerm_postgresql_flexible_server" "this" {
  name                          = "psql-${var.env}"
  location                      = var.location
  resource_group_name           = var.resource_group_name
  version                       = var.postgresql_version
  administrator_login           = var.administrator_login
  administrator_password        = var.administrator_password
  zone                          = "1"
  storage_mb                    = var.storage_mb
  sku_name                      = var.sku_name
  backup_retention_days         = var.backup_retention_days
  geo_redundant_backup_enabled  = var.geo_redundant_backup_enabled
  public_network_access_enabled = false

  # VNet インジェクション
  delegated_subnet_id = var.subnet_id
  private_dns_zone_id = var.private_dns_zone_id

  tags = var.tags
}

resource "azurerm_postgresql_flexible_server_database" "app" {
  name      = var.db_name
  server_id = azurerm_postgresql_flexible_server.this.id
  charset   = "UTF8"
  collation = "en_US.utf8"
}

# PostgreSQL の診断ログを Log Analytics へ転送
resource "azurerm_monitor_diagnostic_setting" "postgresql" {
  name                       = "diag-psql-${var.env}"
  target_resource_id         = azurerm_postgresql_flexible_server.this.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "PostgreSQLLogs"
  }

  metric {
    category = "AllMetrics"
  }
}
