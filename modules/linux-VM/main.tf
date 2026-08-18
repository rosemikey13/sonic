resource "azurerm_subnet" "application_subnet" {
  virtual_network_name = var.vn_name
  name = "${var.application_name}-subnet"
  address_prefixes =[var.application_subnet_cidr_block]
  resource_group_name = var.rg_name
}

resource "azurerm_public_ip" "application_public_ip" {
  location = var.vn_location
  resource_group_name = var.rg_name
  name = "${var.application_name}-public-ip"
  
  lifecycle {
    create_before_destroy = true
  }
  allocation_method = "Static"

}

resource "azurerm_network_interface" "application_ni" {
  resource_group_name = var.rg_name
  name = "${var.application_name}-network-interface"
  location = var.vn_location
  ip_configuration {
    name = "${var.application_name}-ni-ip-config"
    subnet_id = azurerm_subnet.application_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id = azurerm_public_ip.application_public_ip.id
  }
}

data "http" "public_ip_addr" {
  count =  var.my_ip == "" ? 1 : 0
  url = "https://ipinfo.io/ip"
}

resource "azurerm_network_security_group" "application_network_sg" {
  name = "${var.application_name}-network-security-group"
  location = var.vn_location
  resource_group_name = var.rg_name
  
  security_rule {
    name = "${var.application_name}-inbound-sr"
    priority = 100
    direction = "Inbound"
    access = "Allow"
    protocol = "Tcp"
    source_port_range = "*"
    destination_port_range = "*"
    source_address_prefix = "${coalesce(var.my_ip, length(data.http.public_ip_addr) > 0 ? data.http.public_ip_addr[0].response_body : null)}/32"
    destination_address_prefix = "*"
  }


  security_rule {
    name = "${var.application_name}-outbound-sr"
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

resource "azurerm_network_interface_security_group_association" "application_ni_sg_association" {
  network_security_group_id = azurerm_network_security_group.application_network_sg.id
  network_interface_id = azurerm_network_interface.application_ni.id
}

resource "azurerm_linux_virtual_machine" "application_name" {
  resource_group_name = var.rg_name
  name = "${var.application_name}-vm"
  location = var.vn_location
  network_interface_ids = [azurerm_network_interface.application_ni.id]
  admin_username = var.linux_admin
  size = "Standard_D4alds_v7"


  os_disk {
    name = "${var.application_name}-storage"
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
    command = "echo [${var.application_name}] > ansible/hosts"
  }

  provisioner "local-exec" {
    command = "echo '${azurerm_public_ip.application_public_ip.ip_address}' >> ansible/hosts"
  }

  provisioner "local-exec" {
   command = "echo '\n[${var.application_name}:vars]\nansible_ssh_private_key_file=/home/michael/.ssh/id_rsa\nansible_user=${var.linux_admin}\nansible_ssh_common_args=-o StrictHostKeyChecking=no\nansible_python_interpreter=/usr/bin/python3'>> ansible/hosts"
  }

}