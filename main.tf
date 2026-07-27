terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=4.1.0"
    }
  }
}

variable "subscription_id" {
  
}

variable "host_ip" {
  
}
variable "linux_admin" {
  sensitive = true
}


provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}


resource "azurerm_resource_group" "sonic_rg" {
  name = "sonic-rg"
  location = "East US"
}

resource "azurerm_virtual_network" "sonic_vn" {
  name = "sonic-vn"
  resource_group_name = azurerm_resource_group.sonic_rg.name
  location = azurerm_resource_group.sonic_rg.location
  address_space = ["10.0.0.0/16"]

}

resource "azurerm_subnet" "sonic_prod_subnet" {
  virtual_network_name = azurerm_virtual_network.sonic_vn.name
  name = "sonic-prod-subnet"
  address_prefixes =["10.0.1.0/24"]
  resource_group_name = azurerm_resource_group.sonic_rg.name
}

resource "azurerm_public_ip" "artifactory_public_ip" {
  location = azurerm_virtual_network.sonic_vn.location
  resource_group_name = azurerm_resource_group.sonic_rg.name

  name = "artifactory-public-ip"
  lifecycle {
    create_before_destroy = true
  }
  allocation_method = "Static"
}

resource "azurerm_network_interface" "artifactory_ni" {
  resource_group_name = azurerm_resource_group.sonic_rg.name
  name = "artifactory-network-interface"
  location = azurerm_virtual_network.sonic_vn.location
  ip_configuration {
    name = "artifactory_ni_ip_config"
    subnet_id = azurerm_subnet.sonic_prod_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id = azurerm_public_ip.artifactory_public_ip.id
  }
}



resource "azurerm_network_security_group" "sonic_network_sg" {
  name = "sonic-network-security-group"
  location = azurerm_virtual_network.sonic_vn.location
  resource_group_name = azurerm_resource_group.sonic_rg.name
  

  security_rule {
    name = "artifactory-inbound-sr"
    priority = 100
    direction = "Inbound"
    access = "Allow"
    protocol = "Tcp"
    source_port_range = "*"
    destination_port_range = "*"
    source_address_prefix = var.host_ip
    destination_address_prefix = "*"
  }


  security_rule {
    name = "artifactory-outbound-sr"
    priority = 100
    direction = "Outbound"
    access = "Allow"
    protocol = "Tcp"
    source_port_range = "*"
    destination_port_range = "*"
    source_address_prefix = "*"
    destination_address_prefix = "*"
  }

}

resource "azurerm_subnet_network_security_group_association" "sonic_prod_subnet_sg_association" {
  network_security_group_id = azurerm_network_security_group.sonic_network_sg.id
  subnet_id = azurerm_subnet.sonic_prod_subnet.id
}

resource "azurerm_linux_virtual_machine" "artifactory_1" {
  resource_group_name = azurerm_resource_group.sonic_rg.name
  name = "artifactory-1"
  location = azurerm_virtual_network.sonic_vn.location
  network_interface_ids = [azurerm_network_interface.artifactory_ni.id]
  admin_username = var.linux_admin
  size ="Standard_D2alds_v7"
  priority = "Spot"
  eviction_policy = "Deallocate"


  os_disk {
    name = "artificatory-1"
    storage_account_type = "Standard_LRS"
    caching = "ReadWrite"
  }
  
  source_image_reference {
    offer = "ubuntu-24_04-lts"
    sku = "server"
    publisher = "Canonical"
    version = "latest"
  }
  admin_ssh_key {
    public_key = file("/home/michael/.ssh/id_rsa.pub")
    username = var.linux_admin
  }


  provisioner "local-exec" {
    command = "echo [azure] >> hosts"
  }

  provisioner "local-exec" {
    command = "echo '${azurerm_public_ip.artifactory_public_ip.ip_address}' >> hosts"
  }

  provisioner "local-exec" {
   command = "echo '\n[azure:vars]\nansible_ssh_private_key_file=/home/michael/.ssh/id_rsa\nansible_user=${var.linux_admin}' >> hosts"
  }

   provisioner "local-exec" {
   command = "ssh-keyscan -H ${azurerm_public_ip.artifactory_public_ip.ip_address} >> ~/.ssh/known_hosts"
  }

  provisioner "local-exec" {
    command = "rm hosts"
    when = destroy
  }
}
