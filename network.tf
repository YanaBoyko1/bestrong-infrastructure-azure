resource "azurerm_resource_group" "rg" {
  name     = "bestrong-rg"
  location = "West Europe"
}

resource "azurerm_network_security_group" "nsg_app" {
  name                = "nsg-bestrong-app-001"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_network_security_rule" "allow_https_inbound" {
  name                        = "AllowHTTPSInbound"
  priority                    = 1000
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = "Internet"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.nsg_app.name
}

resource "azurerm_network_security_group" "nsg_endpoints" {
  name                = "nsg-bestrong-endpoints-001"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_network_security_rule" "deny_internet_inbound" {
  name                        = "DenyInternetInbound"
  priority                    = 4000
  direction                   = "Inbound"
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "Internet"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.nsg_endpoints.name
}

module "avm-res-network-virtualnetwork" {
  source = "Azure/avm-res-network-virtualnetwork/azurerm"
  version = "~> 0.7" 

  address_space = ["10.0.0.0/16"]
  location      = azurerm_resource_group.rg.location
  name          = "vnet-bestrong-001"
  parent_id     = azurerm_resource_group.rg.id

  subnets = {
    "subnet1" = {
      name             = "subnet-app"
      address_prefixes = ["10.0.1.0/24"] # 256 ip-address

      network_security_group = {
        id = azurerm_network_security_group.nsg_app.id
      }
      # The action grants App Service permission to assign itself a private IP in this subnet.
      delegations = [
        {
          name = "Microsoft.Web/serverFarms"
          service_delegation = {
            name    = "Microsoft.Web/serverFarms"
            actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
          }
        }
      ]
    }
    "subnet2" = {
      name             = "subnet-endpoints"
      address_prefixes = ["10.0.2.0/24"] # 256 ip-address

      network_security_group = {
        id = azurerm_network_security_group.nsg_endpoints.id
      }
    }
  }
}
