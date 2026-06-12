resource "azurerm_log_analytics_workspace" "law" {
  name                = "law-${var.project_name}-001"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "PerGB2018"
  retention_in_days   = var.log_retention_days
}

resource "azurerm_application_insights" "app_insights" {
  name                = "appi-${var.project_name}-001"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  workspace_id        = azurerm_log_analytics_workspace.law.id
  application_type    = "web"
}


resource "azurerm_monitor_diagnostic_setting" "web_app_diagnostics" {
  name                       = var.diagnostic_setting_names["web_app"]
  target_resource_id         = azurerm_linux_web_app.web_app.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.law.id

  # stdout/stderr emitted by application code running inside the container
  enabled_log {
    category = "AppServiceConsoleLogs"
  }

  # Incoming HTTP request logs: method, path, status code, response time
  enabled_log {
    category = "AppServiceHTTPLogs"
  }

  # Platform-level events: restarts, slot swaps, scaling operations, config changes
  enabled_log {
    category = "AppServicePlatformLogs"
  }

  # CPU, memory, request count, and other platform-emitted metrics
  enabled_metric {
    category = "AllMetrics"
  }
}


resource "azurerm_monitor_diagnostic_setting" "kv_diagnostics" {
  name                       = var.diagnostic_setting_names["kv"]
  target_resource_id         = azurerm_key_vault.kv.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.law.id

  # Records every secret/key/certificate operation with caller identity and timestamp
  enabled_log {
    category = "AuditEvent"
  }

  enabled_metric {
    category = "AllMetrics"
  }
}


resource "azurerm_monitor_diagnostic_setting" "sql_diagnostics" {
  name                       = var.diagnostic_setting_names["sql"]
  
  target_resource_id         = azurerm_mssql_database.sql_db.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.law.id

  enabled_log {
    category = "SQLSecurityAuditEvents"
  }

  enabled_metric {
    category = "AllMetrics"
  }
}


# Alert — HTTP 5xx error rate thresholds
resource "azurerm_monitor_metric_alert" "alert_http_5xx" {
  name                = "alert-http5xx-${var.project_name}"
  resource_group_name = azurerm_resource_group.rg.name
  scopes              = [azurerm_linux_web_app.web_app.id]
  description         = "Triggers when the application starts returning an excessive number of 5xx server errors"
  severity            = 1

  criteria {
    metric_namespace = "Microsoft.Web/sites"
    metric_name      = "Http5xx"
    aggregation      = "Total"
    operator         = "GreaterThan"
    threshold        = var.alert_http_5xx_threshold
  }

  window_size = var.alert_evaluation_window
  frequency   = "PT1M"
}

# Alert — Critical CPU utilization (Server pool infrastructure under heavy load)
resource "azurerm_monitor_metric_alert" "alert_cpu_critical" {
  name                = "alert-cpu-${var.project_name}"
  resource_group_name = azurerm_resource_group.rg.name
  scopes              = [azurerm_service_plan.app_plan.id]
  description         = "Triggers when the average CPU percentage consumption exceeds the defined infrastructure threshold"
  severity            = 1

  criteria {
    metric_namespace = "Microsoft.Web/serverfarms"
    metric_name      = "CpuPercentage"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = var.alert_cpu_threshold
  }

  window_size = var.alert_evaluation_window
  frequency   = "PT1M"
}
