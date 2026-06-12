# Returns:
# - tenant_id = your org ID
# - object_id = your personal ID  
# - subscription_id = which billing account
# - client_id = which app is running this
data "azurerm_client_config" "current" {}

resource "random_password" "sql_password" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "azurerm_key_vault" "kv" {
  name                        = "kv-${var.project_name}-001"
  location                    = var.location
  resource_group_name         = azurerm_resource_group.rg.name
  enabled_for_disk_encryption = true
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  sku_name                    = "standard"
  purge_protection_enabled    = true

  # Key enters "soft delete" state and can be recovered.
  # Dynamic retention period from variables (90 days)
  soft_delete_retention_days    = var.kv_soft_delete_retention_days
  
  public_network_access_enabled = true

  network_acls {
    default_action = "Deny"
    bypass         = "AzureServices"
    ip_rules       = ["${var.terraform_client_ip}/32"]
  }

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    secret_permissions = [
      "Get", "Set", "List", "Delete", "Purge", "Recover"
    ]
  }
}

resource "azurerm_key_vault_access_policy" "app_kv_policy" {
  key_vault_id = azurerm_key_vault.kv.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_linux_web_app.web_app.identity[0].principal_id

  secret_permissions = ["Get", "List"]

  depends_on = [azurerm_linux_web_app.web_app]
}

resource "azurerm_key_vault_secret" "sql_pass_secret" {
  name         = "sql-admin-password"
  value        = random_password.sql_password.result
  key_vault_id = azurerm_key_vault.kv.id

  depends_on = [
    azurerm_private_endpoint.pe_kv,
    azurerm_key_vault_access_policy.app_kv_policy
  ]
}

resource "azurerm_key_vault_secret" "storage_key" {
  name         = "storage-access-key"
  value        = azurerm_storage_account.storage.primary_access_key
  key_vault_id = azurerm_key_vault.kv.id

  depends_on = [
    azurerm_private_endpoint.pe_kv,
    azurerm_key_vault_access_policy.app_kv_policy
  ]
}

resource "azurerm_private_dns_zone" "dns_kv" {
  name                = "privatelink.vaultcore.azure.net"
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "dns_link_kv" {
  name                  = "dns-link-kv"
  resource_group_name   = azurerm_resource_group.rg.name
  private_dns_zone_name = azurerm_private_dns_zone.dns_kv.name
  virtual_network_id    = module.avm-res-network-virtualnetwork.resource_id
}

resource "azurerm_private_endpoint" "pe_kv" {
  name                = "pe-kv-${var.project_name}-001"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  subnet_id           = module.avm-res-network-virtualnetwork.subnets["subnet2"].resource_id

  private_service_connection {
    name                           = "kv-privatelink-conn"
    private_connection_resource_id = azurerm_key_vault.kv.id
    is_manual_connection           = false
    subresource_names              = ["vault"]
  }

  private_dns_zone_group {
    name                 = "kv-dns-zone-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.dns_kv.id]
  }
}