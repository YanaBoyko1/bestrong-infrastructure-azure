resource "azurerm_container_registry" "acr" {
  name                  = "cr${var.project_name}001"
  resource_group_name   = azurerm_resource_group.rg.name
  location              = var.location
  sku                   = "Premium"
  data_endpoint_enabled = false

  public_network_access_enabled = false
}

resource "azurerm_role_assignment" "app_acr_pull" {
  scope                = azurerm_container_registry.acr.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_linux_web_app.web_app.identity[0].principal_id

  depends_on = [azurerm_linux_web_app.web_app]
}

resource "azurerm_private_dns_zone" "dns_acr" {
  name                = "privatelink.azurecr.io"
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "dns_link_acr" {
  name                  = "acr-dns-link"
  resource_group_name   = azurerm_resource_group.rg.name
  private_dns_zone_name = azurerm_private_dns_zone.dns_acr.name
  virtual_network_id    = module.avm-res-network-virtualnetwork.resource_id
}

resource "azurerm_private_endpoint" "pe_acr" {
  name                = "pe-acr-${var.project_name}-001"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  subnet_id           = module.avm-res-network-virtualnetwork.subnets["subnet2"].resource_id

  private_service_connection {
    name                           = "acr-privatelink-conn"
    private_connection_resource_id = azurerm_container_registry.acr.id
    is_manual_connection           = false
    subresource_names              = ["registry"]
  }

  private_dns_zone_group {
    name                 = "acr-dns-zone-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.dns_acr.id]
  }
}