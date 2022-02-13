data "azurerm_storage_account" "storageaccount" {
  name                = var.sql_storageaccount
  resource_group_name = var.sql_databaseResourceGroup
}

data "azurerm_subnet" "azuresql_subnet" {
  count                = length(var.sql_subnet_name)
  name                 = var.sql_subnet_name[count.index]
  virtual_network_name = var.sql_virtual_network_name
  resource_group_name  = var.sql_virtual_network_resourcegroup_name
}

locals {
  storage_account = data.azurerm_storage_account.storageaccount
}
resource "random_password" "sql_admin_password" {
  length           = 16
  special          = true
  override_special = "_%@"
  min_special      = 1
  min_lower        = 1
  min_upper        = 1
  min_numeric      = 1
}
resource "azurerm_key_vault_secret" "key_vault_sql_username" {
  name         = var.sql_server_administrator_login
  value        = var.sql_server_administrator_login
  key_vault_id = data.azurerm_key_vault.kv.id
  content_type = "${var.sql_server_administrator_login} username"
}
resource "azurerm_key_vault_secret" "key_vault_sql_password" {
  name         = "${var.sql_server_administrator_login}Password"
  value        = random_password.sql_admin_password.result
  key_vault_id = data.azurerm_key_vault.kv.id
  content_type = "${var.sql_server_administrator_login} password"
}
resource "azurerm_storage_container" "azuresqlvulnerability_container" {
  name                  = "vulnerability-assessment"
  storage_account_name  = var.sql_storageaccount
  container_access_type = "private"
}
resource "azurerm_mssql_server" "azuresql_server" {
  name                         = var.sql_server_name
  resource_group_name          = var.sql_databaseResourceGroup
  location                     = var.sql_server_location
  version                      = "12.0"
  administrator_login          = var.sql_server_administrator_login
  administrator_login_password = random_password.sql_admin_password.result
  minimum_tls_version          = "1.2"
  azuread_administrator {
    login_username = var.email
    object_id      = ""
  }
  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_mssql_virtual_network_rule" "azuresql_virtualnetwork_rule" {
  count     = length(var.sql_subnet_name)
  name      = "vnetrule-${data.azurerm_subnet.azuresql_subnet[count.index].name}"
  server_id = azurerm_mssql_server.azuresql_server.id
  subnet_id = data.azurerm_subnet.azuresql_subnet[count.index].id
}
resource "azurerm_mssql_firewall_rule" "azuresql_allowazureresources" {
  name             = "allow-azure-services"
  server_id        = azurerm_mssql_server.azuresql_server.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}

resource "azurerm_monitor_diagnostic_setting" "azuresql_diagnostic_setting" {
  name                       = "${azurerm_mssql_server.azuresql_server.name}-masterdiag"
  target_resource_id         = "${azurerm_mssql_server.azuresql_server.id}/databases/master"
  log_analytics_workspace_id = var.sql_log_analytics_workspace_id
  storage_account_id         = local.storage_account.id
  log {
    category = "SQLSecurityAuditEvents"
    enabled  = true
    retention_policy {
      enabled = false
    }
  }
  metric {
    category = "AllMetrics"

    retention_policy {
      enabled = false
    }
  }
   lifecycle {
    ignore_changes = [log, metric]
  }
}

resource "azurerm_monitor_diagnostic_setting" "azuresql_database_diagnostic_setting" {
  count                      = length(var.sqldatabase_name)
  name                       = lower("${azurerm_mssql_database.azuresql_database[count.index].name}-diag")
  target_resource_id         = azurerm_mssql_database.azuresql_database[count.index].id
  log_analytics_workspace_id = var.sql_log_analytics_workspace_id
  storage_account_id         = local.storage_account.id

  log {
    category = "SQLSecurityAuditEvents"
    enabled  = true
    retention_policy {
      enabled = false
    }
  }
  metric {
    category = "AllMetrics"

    retention_policy {
      enabled = false
    }
  }
   lifecycle {
    ignore_changes = [log, metric]
  }
}

resource "azurerm_mssql_server_extended_auditing_policy" "azuresqlserverextended_auditing_policy" {
  server_id                               = azurerm_mssql_server.azuresql_server.id
  storage_endpoint                        = local.storage_account.primary_blob_endpoint
  storage_account_access_key              = local.storage_account.primary_access_key
  storage_account_access_key_is_secondary = false
  retention_in_days                       = 10
  log_monitoring_enabled                  = true
}

resource "azurerm_mssql_server_security_alert_policy" "azuresqlserver_security_alert_policy" {
  resource_group_name        = var.databaseResourceGroup
  server_name                = azurerm_mssql_server.azuresql_server.name
  state                      = "Enabled"
  storage_endpoint           = local.storage_account.primary_blob_endpoint
  storage_account_access_key = local.storage_account.primary_access_key
  email_account_admins       = false
  email_addresses            = [""]
  retention_days             = 10


}

resource "azurerm_mssql_server_vulnerability_assessment" "azuresqlserver_vulnerability_assessment" {
  server_security_alert_policy_id = azurerm_mssql_server_security_alert_policy.azuresqlserver_security_alert_policy.id
  storage_container_path          = "${data.azurerm_storage_account.storageaccount.primary_blob_endpoint}${azurerm_storage_container.azuresqlvulnerability_container.name}/"
  storage_account_access_key      = local.storage_account.primary_access_key
  recurring_scans {
    enabled                   = true
    email_subscription_admins = false
    emails                    = [""]
  }

}

resource "azurerm_mssql_database" "azuresql_database" {
  count     = length(var.sqldatabase_name)
  name      = var.sqldatabase_name[count.index]
  server_id = azurerm_mssql_server.azuresql_server.id
  threat_detection_policy {
    state                      = "Enabled"
    email_account_admins       = "Disabled"
    email_addresses            = [""]
    storage_endpoint           = local.storage_account.primary_blob_endpoint
    storage_account_access_key = local.storage_account.primary_access_key
    retention_days             = 10
  }
  long_term_retention_policy {
    weekly_retention = "PT0S"
    week_of_year     = 1
  }
  short_term_retention_policy {
    retention_days = 35
  }
}

resource "azurerm_mssql_database_extended_auditing_policy" "azuresql_database_auditing_loganalytics" {
  database_id                = "${azurerm_mssql_server.azuresql_server.id}/databases/master"
  storage_endpoint           = local.storage_account.primary_blob_endpoint
  storage_account_access_key = local.storage_account.primary_access_key
  retention_in_days          = 10
  log_monitoring_enabled     = true
}
resource "azurerm_mssql_database_extended_auditing_policy" "azuresql_database_auditing_storage" {
  count                                   = length(var.sqldatabase_name)
  database_id                             = azurerm_mssql_database.azuresql_database[count.index].id
  storage_endpoint                        = local.storage_account.primary_blob_endpoint
  storage_account_access_key              = local.storage_account.primary_access_key
  storage_account_access_key_is_secondary = false
  retention_in_days                       = 10
  log_monitoring_enabled                  = true
}

// Enable automatic tuning
resource "null_resource" "automatictuning" {
  depends_on = [azurerm_mssql_database.azuresql_database]

  triggers = {
    always_run = timestamp()
  }

  provisioner "local-exec" {
    command = "sqlcmd -S ${azurerm_mssql_server.azuresql_server.name}.database.windows.net -d ${azurerm_mssql_database.azuresql_database.name} -U ${var.sqladminuser} -P ${random_password.sql_admin_password.result} -i ./auto-tuning.sql"
  }
}
