# Terraform configuration for Azure Data Factory

resource "azurerm_data_factory" "adf" {
  name                = "${var.prefix}-adf"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  identity { type = "SystemAssigned" }
  tags = local.tags
}
