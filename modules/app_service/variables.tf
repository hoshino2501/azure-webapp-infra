variable "env" {
  type        = string
  description = "環境名 (dev / staging / prod)"
}

variable "suffix" {
  type        = string
  description = "App Service 名のサフィックス (グローバル一意性のため)"
}

variable "location" {
  type        = string
  description = "Azureリージョン"
}

variable "resource_group_name" {
  type        = string
  description = "リソースグループ名"
}

variable "sku_name" {
  type        = string
  description = "App Service Plan の SKU (例: B1, P1v3)"
  default     = "B1"
}

variable "always_on" {
  type        = bool
  description = "Always On を有効化するか"
  default     = false
}

variable "subnet_id" {
  type        = string
  description = "VNet 統合用サブネットの ID"
}

variable "docker_image_name" {
  type        = string
  description = "Docker イメージ名 (例: myapp:latest)"
  default     = "nginx:latest"
}

variable "docker_registry_url" {
  type        = string
  description = "コンテナレジストリの URL"
  default     = "https://index.docker.io"
}

variable "docker_registry_username" {
  type        = string
  description = "コンテナレジストリのユーザー名"
  default     = ""
  sensitive   = true
}

variable "docker_registry_password" {
  type        = string
  description = "コンテナレジストリのパスワード"
  default     = ""
  sensitive   = true
}

variable "app_port" {
  type        = number
  description = "アプリケーションのポート番号"
  default     = 8000
}

variable "db_admin_login" {
  type        = string
  description = "DB 管理者ユーザー名"
}

variable "db_fqdn" {
  type        = string
  description = "PostgreSQL サーバーの FQDN"
}

variable "db_name" {
  type        = string
  description = "データベース名"
  default     = "appdb"
}

variable "key_vault_uri" {
  type        = string
  description = "Key Vault の URI"
}

variable "entra_tenant_id" {
  type        = string
  description = "Microsoft Entra テナント ID"
}

variable "entra_client_id" {
  type        = string
  description = "Microsoft Entra アプリケーション クライアント ID"
}

variable "app_insights_connection_string" {
  type        = string
  description = "Application Insights の接続文字列"
  default     = ""
}

variable "log_analytics_workspace_id" {
  type        = string
  description = "Log Analytics Workspace の ID"
}

variable "additional_app_settings" {
  type        = map(string)
  description = "追加のアプリケーション設定"
  default     = {}
}

variable "tags" {
  type        = map(string)
  description = "リソースに付与するタグ"
  default     = {}
}
