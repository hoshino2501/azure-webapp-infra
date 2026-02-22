terraform {
  required_providers {
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.0"
    }
  }
}

# アプリケーション登録
resource "azuread_application" "this" {
  display_name     = "app-${var.env}-${var.app_display_name}"
  sign_in_audience = "AzureADandPersonalMicrosoftAccount"

  web {
    redirect_uris = var.redirect_uris

    implicit_grant {
      access_token_issuance_enabled = false
      id_token_issuance_enabled     = true
    }
  }

  required_resource_access {
    resource_app_id = "00000003-0000-0000-c000-000000000000" # Microsoft Graph

    resource_access {
      id   = "37f7f235-527c-4136-accd-4a02d197296e" # openid
      type = "Scope"
    }

    resource_access {
      id   = "14dad69e-099b-42c9-810b-d002981feec1" # profile
      type = "Scope"
    }

    resource_access {
      id   = "64a6cdd6-aab1-4aaf-94b8-3cc8405e90d0" # email
      type = "Scope"
    }
  }

  tags = ["environment:${var.env}"]
}

# サービスプリンシパル
resource "azuread_service_principal" "this" {
  client_id                    = azuread_application.this.client_id
  app_role_assignment_required = false
}

# クライアントシークレット
resource "azuread_application_password" "this" {
  application_id = azuread_application.this.id
  display_name   = "app-secret-${var.env}"
  end_date       = var.client_secret_expiry
}
