# Create a resource group
resource "azurerm_resource_group" "az_main_tier_RG" {
  name     = "threetier-resources"
  location = "France Central"
}

# Create a virtual network within the resource group
resource "azurerm_virtual_network" "az_main_tier_Vnet" {
  name                = "example-network"
  resource_group_name = azurerm_resource_group.az_main_tier_RG.name
  location            = azurerm_resource_group.az_main_tier_RG.location
  address_space       = ["10.0.0.0/16"]
}

###################################################################################################################
#WEB SERVER  TIER
variable "WEB_prefix" {
  default = "az_WEB_threetier"
}

resource "azurerm_subnet" "SUBnet1" {
  name                 = "web_az_internal"
  resource_group_name  = azurerm_resource_group.az_main_tier_RG.name
  virtual_network_name = azurerm_virtual_network.az_main_tier_Vnet.name
  address_prefixes     = ["10.0.2.0/24"]
}

# Network Security Group to control inbound/outbound traffic for NIC/subnet
resource "azurerm_network_security_group" "WEB" {
  name                = "${var.WEB_prefix}-nsg"
  location            = azurerm_resource_group.az_main_tier_RG.location
  resource_group_name = azurerm_resource_group.az_main_tier_RG.name

  security_rule {
    name                       = "AllowSSHFromMyIP"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "197.63.218.102/32" # YOUR PUBLIC IP
    destination_address_prefix = "*"
    description                = "Allow SSH from my IP only"
  }
}

resource "azurerm_network_interface" "WEB" {
  name                = "${var.WEB_prefix}-nic"
  location            = azurerm_resource_group.az_main_tier_RG.location
  resource_group_name = azurerm_resource_group.az_main_tier_RG.name

  ip_configuration {
    name                          = "web-ip-configuration"
    subnet_id                     = azurerm_subnet.SUBnet1.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id         = azurerm_public_ip.WEB_IP.id
  }
}

# Associate the NSG with the NIC so the security rules apply
resource "azurerm_network_interface_security_group_association" "WEB" {
  network_interface_id      = azurerm_network_interface.WEB.id
  network_security_group_id = azurerm_network_security_group.WEB.id
}

resource "azurerm_virtual_machine" "WEB" {
  name                  = "${var.WEB_prefix}-vm"
  location              = azurerm_resource_group.az_main_tier_RG.location
  resource_group_name   = azurerm_resource_group.az_main_tier_RG.name
  network_interface_ids = [azurerm_network_interface.WEB.id]
  # Specify one or more availability zones. Example:
  #   -var 'zones=["2"]' or -var 'zones=["2","3"]'
  zones = var.zone2
  vm_size               = "Standard_B2s"  # 2 vCPUs instead of 4

  delete_os_disk_on_termination = true
  delete_data_disks_on_termination = true

  storage_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }
  storage_os_disk {
    name              = "webosdisk2"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }
  os_profile {
    computer_name  = "web-az-threetier-vm"
    admin_username = "moazadmin"
  }
  os_profile_linux_config {
    disable_password_authentication = true

    ssh_keys {
      # Use the standard Linux authorized_keys path for the VM's admin user.
      path     = "/home/moazadmin/.ssh/authorized_keys"
      key_data = file(pathexpand(var.ssh_pub_key_path))
    }
  }
  tags = {
    environment = "staging"
  }
}
resource "azurerm_public_ip" "WEB_IP" {
  name                = "${var.WEB_prefix}-pip"
  location            = azurerm_resource_group.az_main_tier_RG.location
  resource_group_name = azurerm_resource_group.az_main_tier_RG.name
  allocation_method   = "Static"
  sku                 = "Standard"
}
##=============================================================================================
variable "app_prefix" {
  default = "az_app_threetier"
}

resource "azurerm_subnet" "app_SUBnet2" {
  name                 = "app_az_internal2"
  resource_group_name  = azurerm_resource_group.az_main_tier_RG.name
  virtual_network_name = azurerm_virtual_network.az_main_tier_Vnet.name
  address_prefixes     = ["10.0.3.0/24"]
}

# Network Security Group to control inbound/outbound traffic for NIC/subnet
resource "azurerm_network_security_group" "app_NSG2" {
  name                = "${var.app_prefix}-nsg"
  location            = azurerm_resource_group.az_main_tier_RG.location
  resource_group_name = azurerm_resource_group.az_main_tier_RG.name

  security_rule {
    name                       = "AllowSSHFromwebtier"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "197.63.218.102/32" # YOUR PUBLIC IP
    destination_address_prefix = "*"
    description                = "Allow SSH from web "
  }
}

resource "azurerm_network_interface" "NIC2_app" {
  name                = "${var.app_prefix}-nic"
  location            = azurerm_resource_group.az_main_tier_RG.location
  resource_group_name = azurerm_resource_group.az_main_tier_RG.name

  ip_configuration {
    name                          = "ip_app_configuration"
    subnet_id                     = azurerm_subnet.app_SUBnet2.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id         = azurerm_public_ip.app_ip.id
  }
}

# Associate the NSG with the NIC so the security rules apply
resource "azurerm_network_interface_security_group_association" "app_NIC2_association" {
  network_interface_id      = azurerm_network_interface.NIC2_app.id
  network_security_group_id = azurerm_network_security_group.app_NSG2.id
}

resource "azurerm_virtual_machine" "main" {
  name                  = "${var.app_prefix}-vm"
  location              = azurerm_resource_group.az_main_tier_RG.location
  resource_group_name   = azurerm_resource_group.az_main_tier_RG.name
  network_interface_ids = [azurerm_network_interface.NIC2_app.id]
  # Specify one or more availability zones. Example:
  #   -var 'zones=["2"]' or -var 'zones=["2","3"]'
  zones = var.zone2
  vm_size               = "Standard_B2s"  # 2 vCPUs instead of 4

  delete_os_disk_on_termination = true
  delete_data_disks_on_termination = true

  storage_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }
  storage_os_disk {
    name              = "apposdisk2"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }
  os_profile {
    computer_name  = "app-az-threetier-vm"
    admin_username = "moazadmin"
  }
  os_profile_linux_config {
    disable_password_authentication = true

    ssh_keys {
      # Use the standard Linux authorized_keys path for the VM's admin user.
      path     = "/home/moazadmin/.ssh/authorized_keys"
      key_data = file(pathexpand(var.ssh_pub_key_path))
    }
  }
  tags = {
    environment = "staging"
  }
}
resource "azurerm_public_ip" "app_ip" {
  name                = "${var.app_prefix}-pip"
  location            = azurerm_resource_group.az_main_tier_RG.location
  resource_group_name = azurerm_resource_group.az_main_tier_RG.name
  allocation_method   = "Static"
  sku                 = "Standard"
}
# resource "azurerm_ssh_public_key" "example" {
#   name                = "example"
#   resource_group_name = "example"
#   location            = "West Europe"
#   public_key          = file("~/.ssh/id_rsa.pub")
# }
#==============================================================================================

resource "azurerm_mssql_server" "az_threetier_sqlserver" {
  name                         = "threetier-sqlserver-moaz2024"
  resource_group_name          = azurerm_resource_group.az_main_tier_RG.name
  location                     = azurerm_resource_group.az_main_tier_RG.location
  version                      = "12.0"
  administrator_login          = "4dm1n157r470r"
  administrator_login_password = "4-v3ry-53cr37-p455w0rd"
}

resource "azurerm_mssql_database" "az_threetier_db" {
  name         = "example-db"
  server_id    = azurerm_mssql_server.az_threetier_sqlserver.id
  collation    = "SQL_Latin1_General_CP1_CI_AS"
  license_type = "LicenseIncluded"
  max_size_gb  = 2
  sku_name     = "S0"
  enclave_type = "VBS"

  tags = {
    foo = "bar"
  }

  # prevent the possibility of accidental data loss
  lifecycle {
    prevent_destroy = true
  }
}