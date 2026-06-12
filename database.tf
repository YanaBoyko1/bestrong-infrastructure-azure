resource "azurerm_mssql_server" "sql_server" {
  name                         = "sql-${var.project_name}-001"
  resource_group_name          = azurerm_resource_group.rg.name
  location                     = var.location
  version                      = "12.0"
  administrator_login          = var.sql_admin_login
  administrator_login_password = random_password.sql_password.result

  public_network_access_enabled = false
}

resource "azurerm_mssql_database" "sql_db" {
  name         = "sql_db"
  server_id    = azurerm_mssql_server.sql_server.id
  license_type = "BasePrice"

  sku_name = var.sql_sku

  # Production guardrail: Terraform will throw an error and abort the pipeline 
  # if any command accidentally tries to destroy this critical database state.
  # lifecycle {
  #   prevent_destroy = true
  # }
}


resource "azurerm_private_dns_zone" "dns_sql" {
  name                = "privatelink.database.windows.net"
  resource_group_name = azurerm_resource_group.rg.name
}


resource "azurerm_private_dns_zone_virtual_network_link" "dns_link_sql" {
  name                  = "dns_link_sql"
  resource_group_name   = azurerm_resource_group.rg.name
  private_dns_zone_name = azurerm_private_dns_zone.dns_sql.name
  virtual_network_id    = module.avm-res-network-virtualnetwork.resource_id
}


resource "azurerm_private_endpoint" "pe_sql" {
  name                = "pe-sql-${var.project_name}-001"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  subnet_id           = module.avm-res-network-virtualnetwork.subnets["subnet2"].resource_id

  private_service_connection {
    name                           = "sql-privatelink-conn"
    private_connection_resource_id = azurerm_mssql_server.sql_server.id
    is_manual_connection           = false
    subresource_names              = ["sqlServer"]
  }

  private_dns_zone_group {
    name                 = "sql-dns-zone-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.dns_sql.id]
  }
}

