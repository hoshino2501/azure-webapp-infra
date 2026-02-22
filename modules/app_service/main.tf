resource "azurerm_service_plan" "this" {
  name                = "asp-${var.env}"
  location            = var.location
  resource_group_name = var.resource_group_name
  os_type             = "Linux"
  sku_name            = var.sku_name

  tags = var.tags
}

resource "azurerm_linux_web_app" "this" {
  name                      = "app-${var.env}-${var.suffix}"
  location                  = var.location
  resource_group_name       = var.resource_group_name
  service_plan_id           = azurerm_service_plan.this.id
  virtual_network_subnet_id = var.subnet_id
  https_only                = true

  identity {
    type = "SystemAssigned"
  }

  site_config {
    always_on        = var.always_on
    ftps_state       = "Disabled"
    http2_enabled    = true
    minimum_tls_version = "1.2"

    application_stack {
      docker_image_name        = var.docker_image_name
      docker_registry_url      = var.docker_registry_url
      docker_registry_username = var.docker_registry_username
      docker_registry_password = var.docker_registry_password
    }
  }

  app_settings = merge(
    {
      "WEBSITES_PORT"                    = tostring(var.app_port)
      "DATABASE_URL"                     = "postgresql://${var.db_admin_login}@${var.db_fqdn}/${var.db_name}?sslmode=require"
      "KEY_VAULT_URI"                    = var.key_vault_uri
      "ENTRA_AUTHORITY"                  = "https://login.microsoftonline.com/${var.entra_tenant_id}"
      "ENTRA_CLIENT_ID"                  = var.entra_client_id
      "APPLICATIONINSIGHTS_CONNECTION_STRING" = var.app_insights_connection_string
      "WEBSITES_ENABLE_APP_SERVICE_STORAGE" = "false"
    },
    var.additional_app_settings
  )

  logs {
    http_logs {
      retention_in_days = 7
    }
    application_logs {
      file_system_level = "Warning"
    }
  }

  tags = var.tags
}

# App Service の診断ログを Log Analytics へ転送
resource "azurerm_monitor_diagnostic_setting" "app_service" {
  name                       = "diag-app-${var.env}"
  target_resource_id         = azurerm_linux_web_app.this.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "AppServiceHTTPLogs"
  }

  enabled_log {
    category = "AppServiceConsoleLogs"
  }

  enabled_log {
    category = "AppServiceAppLogs"
  }

  metric {
    category = "AllMetrics"
  }
}
