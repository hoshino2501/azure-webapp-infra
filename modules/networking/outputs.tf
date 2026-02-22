output "vnet_id" {
  description = "Virtual Network の ID"
  value       = azurerm_virtual_network.this.id
}

output "vnet_name" {
  description = "Virtual Network の名前"
  value       = azurerm_virtual_network.this.name
}

output "subnet_app_service_id" {
  description = "App Service 統合用サブネットの ID"
  value       = azurerm_subnet.app_service.id
}

output "subnet_postgresql_id" {
  description = "PostgreSQL フレキシブルサーバー用サブネットの ID"
  value       = azurerm_subnet.postgresql.id
}

output "private_dns_zone_postgresql_id" {
  description = "PostgreSQL 用プライベート DNS ゾーンの ID"
  value       = azurerm_private_dns_zone.postgresql.id
}

output "private_dns_zone_postgresql_name" {
  description = "PostgreSQL 用プライベート DNS ゾーン名"
  value       = azurerm_private_dns_zone.postgresql.name
}
