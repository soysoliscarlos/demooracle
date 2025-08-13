variable "owner" {
  description = "Owner/Contact tag"
  type        = string
  default     = "carlos"
}

variable "environment" {
  description = "Env tag"
  type        = string
  default     = "demo"
}

variable "extra_tags" {
  description = "Extra tags map"
  type        = map(string)
  default     = {}
}

variable "prefix" {
  description = "Prefijo de nombres para los recursos"
  type        = string
  default     = "oracle-demo"
}

variable "rg_name" {
  description = "Nombre del Resource Group"
  type        = string
  default     = "rg-oracle-demo"
}

variable "location" {
  description = "Región de Azure"
  type        = string
  default     = "eastus"
}

variable "vnet_cidr" {
  description = "CIDR para la VNet"
  type        = string
  default     = "10.80.0.0/16"
}

variable "subnet_cidr" {
  description = "CIDR para la Subnet"
  type        = string
  default     = "10.80.1.0/24"
}

variable "my_ip" {
  description = "Tu IP pública con /32 para permitir SSH y 1521 (ej: 203.0.113.10/32)"
  type        = string
}

variable "vm_size" {
  description = "Tamaño de la VM"
  type        = string
  default     = "Standard_B2ms"
}

variable "admin_username" {
  description = "Usuario admin de la VM"
  type        = string
  default     = "azureuser"
}

variable "ssh_public_key_path" {
  description = "Ruta al archivo de llave pública SSH"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

variable "oracle_password" {
  description = "Contraseña para el usuario SYS y APP_USER=demo en Oracle XE"
  type        = string
  sensitive   = true
}

variable "kv_purge_protection" {
  description = "Habilita purge protection en Key Vault"
  type        = bool
  default     = false
}
