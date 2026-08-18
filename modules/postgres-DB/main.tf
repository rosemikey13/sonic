
resource "azurerm_subnet" "application_db_subnet" {
  virtual_network_name = var.vn_name
  name = "${var.application_name}-db-subnet"
  address_prefixes = [var.db_subnet_cidr_block]
  resource_group_name = var.rg_name

  service_endpoint {
    service = "Microsoft.Storage"
  }

  delegation {
    name = "fs"
    service_delegation {
      name = "Microsoft.DBforPostgreSQL/flexibleServers"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action",
      ]
    }
  }

}


resource "azurerm_network_security_group" "application_db_network_sg" {
  name = "${var.application_name}-db-network-security-group"
  location = var.vn_location
  resource_group_name = var.rg_name
  

  security_rule {
    name = "${var.application_name}-db-inbound-sr"
    priority = 100
    direction = "Inbound"
    access = "Allow"
    protocol = "Tcp"
    source_port_range = "*"
    destination_port_range = "*"
    source_address_prefix = "*"
    destination_address_prefix = "*"
  }


  security_rule {
    name = "${var.application_name}-db-outbound-sr"
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

resource "azurerm_subnet_network_security_group_association" "application_db_network_sg" {
  network_security_group_id = azurerm_network_security_group.application_db_network_sg.id
  subnet_id = azurerm_subnet.application_db_subnet.id
}

resource "azurerm_private_dns_zone" "application_db_private_dns_zone" {
  name = "artifactory-db.postgres.database.azure.com"
  resource_group_name = var.rg_name
}

resource "azurerm_private_dns_zone_virtual_network_link" "application_db_private_dns_zone_virtual_network_link" {
  name = "${var.application_name}-db.postgres.database.azure.com"
  private_dns_zone_id = azurerm_private_dns_zone.application_db_private_dns_zone.id
  virtual_network_id  = var.vn_id
  depends_on          = [azurerm_subnet.application_db_subnet]
}


resource "azurerm_postgresql_flexible_server" "application_db_server" {
  name = "${var.application_name}-postgres-db-server"
  resource_group_name = var.rg_name
  location = var.vn_location
  version                = "16"
  administrator_login    = var.psql_admin
  administrator_password = var.psql_password
  storage_mb             = 32768
  sku_name               = "GP_Standard_D4s_v3"
  backup_retention_days = 7
  public_network_access_enabled = false
  delegated_subnet_id = azurerm_subnet.application_db_subnet.id
  private_dns_zone_id = azurerm_private_dns_zone.application_db_private_dns_zone.id



  authentication {
    password_auth_enabled = true
  }

  
  provisioner "local-exec" {
    command = "echo 'DB_USER: ${self.administrator_login}' > ansible/${var.application_name}/vars/db_vars.yaml"
  }

  provisioner "local-exec" {
    command = "echo 'DB_ENDPOINT: ${self.name}.postgres.database.azure.com' >> ansible/${var.application_name}/vars/db_vars.yaml"
  }

  provisioner "local-exec" {
    command = "echo 'DB_PASSWORD: ${self.administrator_password}' >> ansible/${var.application_name}/vars/db_vars.yaml"
  }

   depends_on = [azurerm_private_dns_zone_virtual_network_link.application_db_private_dns_zone_virtual_network_link]
}

resource "azurerm_postgresql_flexible_server_firewall_rule" "application_db_server_firewall_rule" {
  name             = "${var.application_name}-db-server-firewall-rule"
  server_id        = azurerm_postgresql_flexible_server.application_db_server.id
  start_ip_address = var.application_private_ip
  end_ip_address   = var.application_private_ip
}

resource "azurerm_postgresql_flexible_server_database" "application_db" {
  name = "${var.application_name}_db"
  server_id = azurerm_postgresql_flexible_server.application_db_server.id
  collation = "en_US.utf8"
  charset   = "UTF8"


  provisioner "local-exec" {
    command = "echo 'DB_NAME: ${self.name}' >> ansible/${var.application_name}/vars/db_vars.yaml"
  }

}