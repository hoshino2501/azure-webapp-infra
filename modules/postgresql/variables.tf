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

variable "postgresql_version" {
  type        = string
  description = "PostgreSQL バージョン"
  default     = "16"
}

variable "administrator_login" {
  type        = string
  description = "DB 管理者ユーザー名"
}

variable "administrator_password" {
  type        = string
  description = "DB 管理者パスワード"
  sensitive   = true
}

variable "storage_mb" {
  type        = number
  description = "ストレージ容量 (MB)"
  default     = 32768
}

variable "sku_name" {
  type        = string
  description = "SKU 名 (例: B_Standard_B1ms, GP_Standard_D2s_v3)"
  default     = "B_Standard_B1ms"
}

variable "backup_retention_days" {
  type        = number
  description = "バックアップ保持期間 (日)"
  default     = 7
}

variable "geo_redundant_backup_enabled" {
  type        = bool
  description = "geo 冗長バックアップを有効化するか"
  default     = false
}

variable "db_name" {
  type        = string
  description = "作成するデータベース名"
  default     = "appdb"
}

variable "subnet_id" {
  type        = string
  description = "PostgreSQL フレキシブルサーバー用サブネットの ID"
}

variable "private_dns_zone_id" {
  type        = string
  description = "PostgreSQL 用プライベート DNS ゾーンの ID"
}

variable "log_analytics_workspace_id" {
  type        = string
  description = "Log Analytics Workspace の ID"
}

variable "tags" {
  type        = map(string)
  description = "リソースに付与するタグ"
  default     = {}
}
