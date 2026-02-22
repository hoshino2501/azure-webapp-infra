variable "env" {
  type        = string
  description = "環境名 (dev / staging / prod)"
}

variable "suffix" {
  type        = string
  description = "Key Vault 名のサフィックス (グローバル一意性のため)"
}

variable "location" {
  type        = string
  description = "Azureリージョン"
}

variable "resource_group_name" {
  type        = string
  description = "リソースグループ名"
}

variable "purge_protection_enabled" {
  type        = bool
  description = "論理削除の消去保護を有効化するか (prod では true 推奨)"
  default     = false
}

variable "app_service_principal_id" {
  type        = string
  description = "App Service の Managed Identity プリンシパル ID"
}

variable "db_password" {
  type        = string
  description = "DB 管理者パスワード"
  sensitive   = true
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
