provider "azurerm" {
  features {}
  subscription_id = var.azure_subscription_id
}

data "http" "public_ip_addr" {
  count =  var.my_ip == "" ? 1 : 0
  url = "https://ipinfo.io/ip"
}


resource "azurerm_resource_group" "neptune_rg" {
  name = "neptune-rg"
  location = var.location
}

resource "azurerm_network_watcher" "neptune_nwwatcher" {
  name                = "neptune-nwwatcher"
  location            = azurerm_resource_group.neptune_rg.location
  resource_group_name = azurerm_resource_group.neptune_rg.name
}

resource "azurerm_virtual_network" "neptune_vn" {
  name = "neptune-vn"
  resource_group_name = azurerm_resource_group.neptune_rg.name
  location = azurerm_resource_group.neptune_rg.location
  address_space = [var.vn_cidr_block]
}

module "artifactory-vm" {
  source = "./modules/linux-VM"
  application_name = "artifactory"
  application_subnet_cidr_block = var.artifactory_subnet_cidr_block
  linux_admin = var.linux_admin
  rg_name = azurerm_resource_group.neptune_rg.name
  my_ip = var.my_ip
  vn_name = azurerm_virtual_network.neptune_vn.name
  vn_location = azurerm_virtual_network.neptune_vn.location
}

module "artifactory_db" {
  source = "./modules/postgres-DB"
  vn_id = azurerm_virtual_network.neptune_vn.id
  vn_name = azurerm_virtual_network.neptune_vn.name
  vn_location = azurerm_virtual_network.neptune_vn.location
  db_subnet_cidr_block = var.artifactory_db_subnet_cidr_block
  rg_name = azurerm_resource_group.neptune_rg.name
  psql_admin = var.psql_admin
  psql_password = var.psql_password
  application_private_ip = module.artifactory-vm.application_private_ip_address
  application_name = "artifactory"
}



resource "null_resource" "artifactory_playbook_runner" {
  depends_on = [ module.artifactory_db, module.artifactory-vm]
   provisioner "local-exec" {
    command = "ansible-playbook -i ${var.project_path}/ansible/hosts ${var.project_path}/ansible/artifactory-playbook.yaml"
  }
}

