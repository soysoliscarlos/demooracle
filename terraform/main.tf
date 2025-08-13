terraform {
  required_version = ">= 1.0.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 4.39.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.0.0"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = "9993d533-2f66-4fbf-90ec-2920b3ca6051"
}

############################
# 1) Parámetros básicos
############################

locals {
  tags = merge({
    project     = "oracle-demo-2"
    owner       = var.owner
    environment = var.environment
  }, var.extra_tags)
}

############################
# 2) Resource Group
############################
resource "azurerm_resource_group" "rg" {
  name     = var.rg_name
  location = var.location
  tags     = local.tags
}

############################
# 3) Networking
############################
resource "azurerm_virtual_network" "vnet" {
  name                = "${var.prefix}-vnet"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = [var.vnet_cidr]
  tags                = local.tags
}

resource "azurerm_subnet" "snet" {
  name                 = "${var.prefix}-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [var.subnet_cidr]
}

# NSG que restringe SSH y 1521 a tu IP pública
resource "azurerm_network_security_group" "nsg" {
  name                = "${var.prefix}-nsg"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  tags                = local.tags

  security_rule {
    name                       = "Allow-SSH-From-MyIP"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = var.my_ip
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow-Oracle-1521"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "1521"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # Salida general (puedes endurecer con proxy/firewall si deseas)
  security_rule {
    name                       = "Allow-Internet-Out"
    priority                   = 200
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "Internet"
  }

  # Bloquea todo lo demás entrante
  security_rule {
    name                       = "Deny-All-In"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_public_ip" "pip" {
  name                = "${var.prefix}-pip"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = local.tags
}

resource "azurerm_network_interface" "nic" {
  name                = "${var.prefix}-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.snet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.pip.id
  }

  tags = local.tags
}

resource "azurerm_network_interface_security_group_association" "nic_nsg" {
  network_interface_id      = azurerm_network_interface.nic.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

############################
# 4) Key Vault (guardar contraseña Oracle)
############################
resource "random_string" "kv_suffix" {
  length  = 6
  upper   = false
  special = false
}

resource "azurerm_key_vault" "kv" {
  name                = "${var.prefix}-kv-${random_string.kv_suffix.result}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  tenant_id = data.azurerm_client_config.current.tenant_id
  sku_name  = "standard"

  purge_protection_enabled   = var.kv_purge_protection
  soft_delete_retention_days = 7

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    secret_permissions = ["Get", "List", "Set", "Delete", "Recover", "Backup", "Restore"]
  }

  tags = local.tags
}

resource "azurerm_key_vault_access_policy" "adf" {
  key_vault_id = azurerm_key_vault.kv.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_data_factory.adf.identity[0].principal_id

  secret_permissions = ["Get", "List", "Set", "Delete", "Recover", "Backup", "Restore"]
}

data "azurerm_client_config" "current" {}

# Guarda la contraseña de Oracle en KV
resource "azurerm_key_vault_secret" "oracle_pwd" {
  name         = "oracle-admin-password"
  value        = var.oracle_password
  key_vault_id = azurerm_key_vault.kv.id
}

############################
# 5) VM Ubuntu + Docker + Oracle XE (contenedor)
############################

# cloud-init para instalar Docker y arrancar contenedor Oracle XE (gvenzl/oracle-xe)
locals {
  cloud_init = <<-CLOUDINIT
  #cloud-config
  package_update: true
  packages:
    - apt-transport-https
    - ca-certificates
    - curl
    - gnupg
    - lsb-release
  runcmd:
    - |
      set -e
      # Instala Docker
      install -m 0755 -d /etc/apt/keyrings
      curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --yes --dearmor -o /etc/apt/keyrings/docker.gpg
      chmod a+r /etc/apt/keyrings/docker.gpg
      echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
        $(. /etc/os-release && echo $VERSION_CODENAME) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
      apt-get update -y
      apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

      systemctl enable docker
      systemctl start docker

      # Ejecutar Oracle XE (contraseña desde variable inyectada)
      ORACLE_PWD="${var.oracle_password}"
      docker pull gvenzl/oracle-xe:21
      docker run -d --name oracle-xe \
        -p 1521:1521 -p 5500:5500 \
        -e ORACLE_PASSWORD="$ORACLE_PWD" \
        -e APP_USER=demo -e APP_USER_PASSWORD="$ORACLE_PWD" \
        --restart always gvenzl/oracle-xe:21

      # Espera inicial y crea tabla de muestra
      echo "Esperando a que Oracle inicialice (90s)..." && sleep 90

      # Instala sqlplus ligero (instantclient) para poblar demo (opcional)
      apt-get install -y wget unzip libaio1
      cd /tmp
      wget https://download.oracle.com/otn_software/linux/instantclient/219000/instantclient-basiclite-linux.x64-21.9.0.0.0dbru.zip
      unzip instantclient-basiclite-linux.x64-21.9.0.0.0dbru.zip -d /opt
      echo /opt/instantclient_21_9 > /etc/ld.so.conf.d/oracle-instantclient.conf
      ldconfig

      # Crea tabla y datos de ejemplo usando docker exec + sqlplus dentro del contenedor
      docker exec oracle-xe bash -lc "source /home/oracle/.bashrc; echo \"
      CONNECT demo/$ORACLE_PWD@localhost/XEPDB1
      CREATE TABLE employees_demo (employee_id NUMBER PRIMARY KEY, first_name VARCHAR2(50), last_name VARCHAR2(50), salary NUMBER);
      INSERT INTO employees_demo VALUES (1,'Ada','Lovelace',170000);
      INSERT INTO employees_demo VALUES (2,'Grace','Hopper',165000);
      INSERT INTO employees_demo VALUES (3,'Linus','Torvalds',180000);
      COMMIT;
      EXIT
      \" | sqlplus -s /nolog"

      echo "Oracle XE listo."
  CLOUDINIT
}

resource "azurerm_linux_virtual_machine" "vm" {
  name                = "${var.prefix}-vm"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = var.vm_size
  admin_username      = var.admin_username

  network_interface_ids = [
    azurerm_network_interface.nic.id
  ]

  # Ubuntu LTS
  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

  admin_ssh_key {
    username   = var.admin_username
    public_key = file(var.ssh_public_key_path)
  }

  custom_data = base64encode(local.cloud_init)

  os_disk {
    name                 = "${var.prefix}-osdisk"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
    disk_size_gb         = 64
  }

  identity {
    type = "SystemAssigned"
  }

  tags = local.tags
}

############################
# 6) Storage Account (ADLS Gen2) para el sink de ADF
############################
resource "random_string" "stg" {
  length  = 8
  upper   = false
  special = false
}

resource "azurerm_storage_account" "stg" {
  name                     = replace("${var.prefix}stg${random_string.stg.result}", "-", "")
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  # ADLS Gen2
  is_hns_enabled = true

  tags = local.tags
}

resource "azurerm_storage_container" "export" {
  name = "oracle-export"
  # storage_account_name  = azurerm_storage_account.stg.name
  storage_account_id    = azurerm_storage_account.stg.id
  container_access_type = "private"
}

############################
# 7) (Opcional) Rol para que ADF/Self MI acceda a ADLS
############################
# Puedes asignar este rol a la MI de tu Data Factory cuando lo crees
data "azurerm_role_definition" "storage_blob_data_contributor" {
  name  = "Storage Blob Data Contributor"
  scope = azurerm_storage_account.stg.id
}

# Ejemplo (comenta/ajusta cuando tengas el principalId de ADF MI)
# resource "azurerm_role_assignment" "adf_to_adls" {
#   scope                = azurerm_storage_account.stg.id
#   role_definition_id   = data.azurerm_role_definition.storage_blob_data_contributor.role_definition_id
#   principal_id         = "<OBJECT_ID_MI_DE_TU_ADF>"
#   depends_on           = [azurerm_storage_account.stg]
# }

