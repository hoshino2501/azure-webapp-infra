variable "project_name" {
  type        = string
  description = "プロジェクト名"
}

variable "location" {
  type        = string
  description = "Azureリージョン"
  default     = "japaneast"
}

variable "suffix" {
  type        = string
  description = "グローバル一意リソース名のサフィックス"
}

variable "entra_tenant_id" {
  type        = string
  description = "Microsoft Entra テナント ID"
}

variable "vnet_address_space" {
  type        = string
  description = "VNet のアドレス空間 (CIDR)"
  default     = "10.0.0.0/16"
}

variable "subnet_app_service_prefix" {
  type        = string
  description = "App Service 統合用サブネットの CIDR"
  default     = "10.0.1.0/24"
}

variable "subnet_postgresql_prefix" {
  type        = string
  description = "PostgreSQL フレキシブルサーバー用サブネットの CIDR"
  default     = "10.0.2.0/24"
}

variable "app_service_sku" {
  type        = string
  description = "App Service Plan の SKU"
  default     = "B1"
}

variable "docker_image_name" {
  type        = string
  description = "Docker イメージ名"
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

variable "db_admin_login" {
  type        = string
  description = "DB 管理者ユーザー名"
  default     = "pgadmin"
}

variable "db_password" {
  type        = string
  description = "DB 管理者パスワード"
  sensitive   = true
}

variable "db_name" {
  type        = string
  description = "データベース名"
  default     = "appdb"
}

variable "postgresql_sku" {
  type        = string
  description = "PostgreSQL フレキシブルサーバーの SKU"
  default     = "B_Standard_B1ms"
}
