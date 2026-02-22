output "app_service_id" {
  description = "App Service の ID"
  value       = azurerm_linux_web_app.this.id
}

output "app_service_name" {
  description = "App Service の名前"
  value       = azurerm_linux_web_app.this.name
}

output "app_service_default_hostname" {
  description = "App Service のデフォルトホスト名"
  value       = azurerm_linux_web_app.this.default_hostname
}

output "app_service_principal_id" {
  description = "App Service の System Assigned Managed Identity プリンシパル ID"
  value       = azurerm_linux_web_app.this.identity[0].principal_id
}

output "service_plan_id" {
  description = "App Service Plan の ID"
  value       = azurerm_service_plan.this.id
}
