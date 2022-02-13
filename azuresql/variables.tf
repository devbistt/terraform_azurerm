variable "databaseservername" {
  type        = string
  description = "The name of the Microsoft SQL Server. This needs to be globally unique within Azure"
}
variable "databaseResourceGroup" {
  type        = string
  description = "The name of the resource group in which to create the Microsoft SQL Server."

}
variable "databaseserverlocation" {
  type        = string
  description = "The location of the Azure SQL server."

}

variable "sqladminuser" {
  type        = string
  description = "The administrator user name for the sql server"

}

variable "email" {
  type        = string
  description = "Email address to be used for SQL admin account and alerts"
}

variable "objectid" {
  type        = string
  description = "Object Id of the email for SQL admin account and alerts"

}
variable "azuresqlstorageaccount" {
  type        = string
  description = "Threat Detection & audit storage account"

}

variable "sqldatabase_name" {
  type        = list(string)
  description = "List of the sql database names"
}

variable "sql_log_analytics_workspace_id" {
  type        = string
  description = "Resource ID of the Log Analytics workspace"
}

variable "sql_virtual_network_name" {
  type        = string
  description = "Name of the Virtual Network to be enabled in firewall settings"
}

variable "sql_virtual_network_resourcegroup_name" {
  type        = string
  description = "Resource group of the Virtual Network to be enabled in firewall settings"
}

variable "sql_subnet_name" {
  type        = list(string)
  description = "List of the subnet names to be enabled in firewall settings"
}

variable "keyvault_id" {
  type        = string
  description = "Resource ID of the keyvault to update sql admin details"
}
