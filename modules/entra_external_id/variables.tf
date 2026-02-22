variable "env" {
  type        = string
  description = "環境名 (dev / staging / prod)"
}

variable "app_display_name" {
  type        = string
  description = "Entra アプリケーションの表示名"
}

variable "redirect_uris" {
  type        = list(string)
  description = "OAuth2 リダイレクト URI のリスト"
}

variable "client_secret_expiry" {
  type        = string
  description = "クライアントシークレットの有効期限 (RFC3339)"
  default     = "2026-12-31T00:00:00Z"
}
