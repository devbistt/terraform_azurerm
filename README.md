# terraform_azurerm
Terraform modules for the various Azure resources as described below :

1. AzureSQL:
   Module to create an Azure SQL server , database , generate random password & save it in the specified key vault. It also enables diagnostic_setting and auditing/ alert_policy for the databases.