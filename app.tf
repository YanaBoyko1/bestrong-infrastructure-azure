resource "azurerm_service_plan" "app_plan" {
  name                = "asp-${var.project_name}-001"
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.location

  os_type  = "Linux"
  sku_name = var.app_service_sku
}

resource "azurerm_linux_web_app" "web_app" {
  name                = "app-${var.project_name}-001"
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.location
  service_plan_id     = azurerm_service_plan.app_plan.id

  # Enables System-Assigned Managed Identity for secure passwordless authentication
  identity {
    type = "SystemAssigned"
  }

  site_config {
    # Keeps the container warm and running constantly to prevent cold starts
    always_on = true

    application_stack {
      docker_image_name   = var.docker_image_name
      docker_registry_url = "https://${azurerm_container_registry.acr.login_server}"
    }
  }


  app_settings = {
    # Converts the numerical target container application port into a valid Azure string value
    "WEBSITES_PORT" = tostring(var.app_port)

    # Securely references Key Vault secrets natively via Managed Identity references
    "STORAGE_KEY" = "@Microsoft.KeyVault(VaultName=${azurerm_key_vault.kv.vault_uri};SecretName=storage_key)"

    # Application performance monitoring credentials (Log Analytics & Application Insights telemetry)
    "APPINSIGHTS_INSTRUMENTATIONKEY"        = azurerm_application_insights.app_insights.instrumentation_key
    "APPLICATIONINSIGHTS_CONNECTION_STRING" = azurerm_application_insights.app_insights.connection_string
  }

  storage_account {
    name         = "user-uploads-dir"
    type         = "AzureFiles"
    account_name = azurerm_storage_account.storage.name
    share_name   = azurerm_storage_share.user_files.name
    mount_path   = "/app/uploads"

    # Credential token required by the cloud platform engine to physically mount the disk volume
    access_key = azurerm_storage_account.storage.primary_access_key
  }
}


resource "azurerm_app_service_virtual_network_swift_connection" "vnet_integration" {
  app_service_id = azurerm_linux_web_app.web_app.id
  subnet_id      = module.avm-res-network-virtualnetwork.subnets["subnet1"].resource_id
}