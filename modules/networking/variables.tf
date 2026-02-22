variable "env" {
  type        = string
  description = "環境名 (dev / staging / prod)"
}

variable "location" {
  type        = string
  description = "Azureリージョン"
}

variable "resource_group_name" {
  type        = string
  description = "リソースグループ名"
}

variable "vnet_address_space" {
  type        = string
  description = "VNet のアドレス空間 (CIDR)"
}

variable "subnet_app_service_prefix" {
  type        = string
  description = "App Service 統合用サブネットの CIDR"
}

variable "subnet_postgresql_prefix" {
  type        = string
  description = "PostgreSQL フレキシブルサーバー用サブネットの CIDR"
}

variable "tags" {
  type        = map(string)
  description = "リソースに付与するタグ"
  default     = {}
}
