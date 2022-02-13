output "sql_server_fqdn" {
  value = azurerm_mssql_server.azuresql_server.fully_qualified_domain_name
}