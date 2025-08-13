output "vm_public_ip" {
  value       = azurerm_public_ip.pip.ip_address
  description = "IP pública de la VM (ajusta NSG o usa bastion si no quieres exposición)"
}

output "oracle_connect_dsn" {
  value       = "HOST=${azurerm_public_ip.pip.ip_address};PORT=1521;SERVICE_NAME=XEPDB1"
  description = "DSN para clientes Oracle (sqlplus, ADF, etc.)"
}

output "oracle_demo_user" {
  value       = "demo"
  description = "Usuario de aplicación creado por el contenedor"
}

output "oracle_password_secret_id" {
  value       = azurerm_key_vault_secret.oracle_pwd.id
  description = "ID del secreto en Key Vault con la contraseña de Oracle"
  sensitive   = true
}

output "adls_account_name" {
  value       = azurerm_storage_account.stg.name
  description = "Nombre del Storage Account ADLS Gen2 (sink para ADF)"
}

output "adls_container_oracle_export" {
  value       = azurerm_storage_container.export.name
  description = "Contenedor destino para archivos CSV"
}

output "data_factory_id" {
  value = azurerm_data_factory.adf.id
}
