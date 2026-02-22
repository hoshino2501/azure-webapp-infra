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

variable "retention_in_days" {
  type        = number
  description = "ログ保持期間 (日)"
  default     = 30
}

variable "tags" {
  type        = map(string)
  description = "リソースに付与するタグ"
  default     = {}
}
