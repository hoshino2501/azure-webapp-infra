output "workspace_id" {
  description = "Log Analytics Workspace の ID"
  value       = azurerm_log_analytics_workspace.this.id
}

output "workspace_name" {
  description = "Log Analytics Workspace の名前"
  value       = azurerm_log_analytics_workspace.this.name
}
