# Declaring the local variables
locals  {
    storageAccountName          = lower(join("", ["sawinvm", random_string.asaname-01.result]))
    nicName                     = "myVMNic"
    addressPrefix               = "10.0.0.0/16"
    subnetName                  = "Subnet"
    subnetPrefix                = "10.0.0.0/24"
    publicIPAddressName         = "myPublicIP"
    vmName                      = "s00175rkona"
    virtualNetworkName          = "MyVNET"
    networkSecurityGroupName    = "default-NSG"
    osDiskName                  = join("",[local.vmName, "rkim620", lower(random_string.avmosd-01.result)])
}

# Generating the random string to create a unique storage account
resource "random_string" "asaname-01" {
    length  = 16
    special = "false"
}

# Generating the random string to create a unique os disk 
resource "random_string" "avmosd-01" {
    length  = 32
    special = "false"
}

# Resource Group
resource "azurerm_resource_group" "arg-01" {
    name        = var.resourceGroupName
    location    = var.location
}

# Storage Account
resource "azurerm_storage_account" "asa-01" {
    name                        = local.storageAccountName
    resource_group_name         = azurerm_resource_group.arg-01.name
    location                    = azurerm_resource_group.arg-01.location
    account_replication_type    = "LRS"
    account_tier                = "Standard"
}

# Public IP
resource "azurerm_public_ip" "apip-01" {
    name                = local.publicIPAddressName
    resource_group_name = azurerm_resource_group.arg-01.name
    location            = azurerm_resource_group.arg-01.location
    allocation_method   = "Dynamic"
    domain_name_label   = var.dnsLabelPrefix
}

# Network Security Group with allow RDP rule 
resource "azurerm_network_security_group" "ansg-01" {
    name                = local.networkSecurityGroupName
    resource_group_name = azurerm_resource_group.arg-01.name
    location            = azurerm_resource_group.arg-01.location
    security_rule {
        name                        = "default-allow-3389"
        priority                    = 1000
        access                      = "Allow"
        direction                   = "Inbound"
        destination_port_range      = 3389
        protocol                    = "Tcp"
        source_port_range           = "*"
        source_address_prefix       = "*"
        destination_address_prefix  = "*"
    }
	security_rule {
        name                        = "inbound-allow-7717"
        priority                    = 1001
        access                      = "Allow"
        direction                   = "Inbound"
        destination_port_range      = 7717
        protocol                    = "Tcp"
        source_port_range           = "*"
        source_address_prefix       = "*"
        destination_address_prefix  = "*"
    }
	security_rule {
        name                        = "outbound-allow-5282"
        priority                    = 1002
        access                      = "Allow"
        direction                   = "Outbound"
        destination_port_range      = 5282
        protocol                    = "Tcp"
        source_port_range           = "*"
        source_address_prefix       = "*"
        destination_address_prefix  = "*"
    }
}

# Virtual Network
resource "azurerm_virtual_network" "avn-01" {
    name                = local.virtualNetworkName
    resource_group_name = azurerm_resource_group.arg-01.name
    location            = azurerm_resource_group.arg-01.location
    address_space       = [local.addressPrefix]
}

# Subnet
resource "azurerm_subnet" "as-01" {
    name                  = local.subnetName
    resource_group_name   = azurerm_resource_group.arg-01.name
    virtual_network_name  = azurerm_virtual_network.avn-01.name
    address_prefix        = local.subnetPrefix
}

# Associate the subnet with NSG
resource "azurerm_subnet_network_security_group_association" "asnsga-01" {
    subnet_id                   = azurerm_subnet.as-01.id
    network_security_group_id   = azurerm_network_security_group.ansg-01.id
}

# Network Interface Card
resource "azurerm_network_interface" "anic-01" {
    name                = local.nicName
    resource_group_name = azurerm_resource_group.arg-01.name
    location            = azurerm_resource_group.arg-01.location
    ip_configuration {
        name                            = "ipconfig1"
        private_ip_address_allocation   = "Dynamic"
        public_ip_address_id            = azurerm_public_ip.apip-01.id
        subnet_id                       = azurerm_subnet.as-01.id
    }
}

# Virtual Machine
resource "azurerm_virtual_machine" "avm-01" {
    name                    = local.vmName
    resource_group_name     = azurerm_resource_group.arg-01.name
    location                = azurerm_resource_group.arg-01.location
    vm_size                 = var.vmSize
    network_interface_ids   = [azurerm_network_interface.anic-01.id]
    os_profile {
        computer_name   = local.vmName
        admin_username  = var.adminUsername
        admin_password  = var.adminPassword
    }
    storage_image_reference {
        offer       = "Windows-10"
        sku         = var.windowsOSVersion
        version     = "latest"
		id			= "/subscriptions/xxxxxxx/resourceGroups/test12620/providers/Microsoft.Compute/images/rkim620"
    }
    storage_os_disk {
        name            = local.osDiskName
        create_option   = "FromImage"
    }
    storage_data_disk {
        name            = "Data"
        disk_size_gb    = 1023
        lun             = 0
        create_option   = "Empty"
    }
    os_profile_windows_config {
        provision_vm_agent  = true
    }
    boot_diagnostics {
        enabled     = true
        storage_uri = azurerm_storage_account.asa-01.primary_blob_endpoint
    }
}

# Print virtual machine dns name
output "hostname" {
    value   = azurerm_public_ip.apip-01.fqdn
}
