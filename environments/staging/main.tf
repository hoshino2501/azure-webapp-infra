terraform {
  required_version = ">= 1.9"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.0"
    }
  }

  backend "azurerm" {
    resource_group_name  = "rg-tfstate"
    storage_account_name = "" # 初期セットアップ後に記載
    container_name       = "tfstate"
    key                  = "staging/terraform.tfstate"
  }
}

provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy    = false
      recover_soft_deleted_key_vaults = true
    }
  }
}

provider "azuread" {}

locals {
  env      = "staging"
  location = var.location
  tags = {
    Environment = local.env
    ManagedBy   = "Terraform"
    Project     = var.project_name
  }
}

resource "azurerm_resource_group" "this" {
  name     = "rg-${var.project_name}-${local.env}"
  location = local.location

  tags = local.tags
}

module "log_analytics" {
  source = "../../modules/log_analytics"

  env                 = local.env
  location            = local.location
  resource_group_name = azurerm_resource_group.this.name
  retention_in_days   = 60
  tags                = local.tags
}

module "networking" {
  source = "../../modules/networking"

  env                       = local.env
  location                  = local.location
  resource_group_name       = azurerm_resource_group.this.name
  vnet_address_space        = var.vnet_address_space
  subnet_app_service_prefix = var.subnet_app_service_prefix
  subnet_postgresql_prefix  = var.subnet_postgresql_prefix
  tags                      = local.tags
}

module "entra_external_id" {
  source = "../../modules/entra_external_id"

  env              = local.env
  app_display_name = var.project_name
  redirect_uris    = ["https://app-${local.env}-${var.suffix}.azurewebsites.net/.auth/login/aad/callback"]
}

module "app_service" {
  source = "../../modules/app_service"

  env                        = local.env
  suffix                     = var.suffix
  location                   = local.location
  resource_group_name        = azurerm_resource_group.this.name
  sku_name                   = var.app_service_sku
  always_on                  = true
  subnet_id                  = module.networking.subnet_app_service_id
  docker_image_name          = var.docker_image_name
  docker_registry_url        = var.docker_registry_url
  docker_registry_username   = var.docker_registry_username
  docker_registry_password   = var.docker_registry_password
  db_admin_login             = var.db_admin_login
  db_fqdn                    = module.postgresql.server_fqdn
  db_name                    = var.db_name
  key_vault_uri              = module.key_vault.key_vault_uri
  entra_tenant_id            = var.entra_tenant_id
  entra_client_id            = module.entra_external_id.client_id
  log_analytics_workspace_id = module.log_analytics.workspace_id
  tags                       = local.tags
}

module "key_vault" {
  source = "../../modules/key_vault"

  env                        = local.env
  suffix                     = var.suffix
  location                   = local.location
  resource_group_name        = azurerm_resource_group.this.name
  purge_protection_enabled   = false
  app_service_principal_id   = module.app_service.app_service_principal_id
  db_password                = var.db_password
  log_analytics_workspace_id = module.log_analytics.workspace_id
  tags                       = local.tags
}

module "postgresql" {
  source = "../../modules/postgresql"

  env                        = local.env
  location                   = local.location
  resource_group_name        = azurerm_resource_group.this.name
  postgresql_version         = "16"
  administrator_login        = var.db_admin_login
  administrator_password     = var.db_password
  storage_mb                 = 65536
  sku_name                   = var.postgresql_sku
  backup_retention_days      = 14
  db_name                    = var.db_name
  subnet_id                  = module.networking.subnet_postgresql_id
  private_dns_zone_id        = module.networking.private_dns_zone_postgresql_id
  log_analytics_workspace_id = module.log_analytics.workspace_id
  tags                       = local.tags
}
