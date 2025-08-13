# Terraform configuration for Azure Data Factory

resource "azurerm_data_factory" "adf" {
  name                = "${var.prefix}-adf"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  identity { type = "SystemAssigned" }
  tags = local.tags
}

# # Linked Service: Oracle (usando la IP pública de la VM y el secreto de contraseña en Key Vault)
# resource "azurerm_data_factory_linked_service_oracle" "oracle" {
#   name                = "oracle-linked-service"
#   resource_group_name = azurerm_resource_group.rg.name
#   data_factory_id     = azurerm_data_factory.adf.id

#   connection_string = <<-EOT
#     Data Source=(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=${azurerm_public_ip.pip.ip_address})(PORT=1521))(CONNECT_DATA=(SERVICE_NAME=XEPDB1)));
#     User Id=demo;
#     Password=${var.oracle_password};
#   EOT

#   description = "Oracle XE en VM Azure demo"
# }

