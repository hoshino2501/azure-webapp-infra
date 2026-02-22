output "client_id" {
  description = "Entra アプリケーションのクライアント ID"
  value       = azuread_application.this.client_id
}

output "client_secret" {
  description = "Entra アプリケーションのクライアントシークレット"
  value       = azuread_application_password.this.value
  sensitive   = true
}

output "object_id" {
  description = "Entra アプリケーションのオブジェクト ID"
  value       = azuread_application.this.object_id
}

output "service_principal_id" {
  description = "サービスプリンシパルのオブジェクト ID"
  value       = azuread_service_principal.this.object_id
}
