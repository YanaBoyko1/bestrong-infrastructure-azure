resource "azurerm_storage_account" "storage" {
  name                     = "st${var.project_name}001"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = var.storage_replication_type

  public_network_access_enabled = false
}

resource "azurerm_storage_share" "user_files" {
  name               = "userfiles"
  storage_account_id = azurerm_storage_account.storage.id
  quota              = var.storage_share_quota_gb
}

resource "azurerm_private_dns_zone" "dns_storage" {
  name                = "privatelink.file.core.windows.net"
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "dns_link_storage" {
  name                  = "storage-dns-link"
  resource_group_name   = azurerm_resource_group.rg.name
  private_dns_zone_name = azurerm_private_dns_zone.dns_storage.name
  virtual_network_id    = module.avm-res-network-virtualnetwork.resource_id
}

resource "azurerm_private_endpoint" "pe_storage" {
  name                = "pe-storage-${var.project_name}-001"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  subnet_id           = module.avm-res-network-virtualnetwork.subnets["subnet2"].resource_id

  private_service_connection {
    name                           = "storage-privatelink-conn"
    private_connection_resource_id = azurerm_storage_account.storage.id
    is_manual_connection           = false
    subresource_names              = ["file"]
  }

  private_dns_zone_group {
    name                 = "storage-dns-zone-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.dns_storage.id]
  }
}