# BeStrong — Azure Infrastructure

> Terraform infrastructure for the BeStrong application, deployed on Microsoft Azure.

---

## 📋 Table of Contents

- [Project Requirements](#project-requirements)
- [Architecture Overview](#architecture-overview)
- [Project Structure](#project-structure)
- [File Descriptions](#file-descriptions)
- [Azure Resources](#azure-resources)
- [Getting Started](#getting-started)
- [Remote State](#remote-state)
- [CI/CD schemee](#ci/cd-scheme)

---

## Project Requirements

The client (BeStrong) requested the following infrastructure:

Where our code will live — we need something to run our backend. We don't want VMs — too much hassle with updates and security. We want something managed where we just deploy our code and it works. Also important: we want this thing to "introduce itself" to other Azure services without passwords. And it should sit inside our private network, not be exposed to the outside more than necessary. 
See what's happening — when something crashes, we want to know why. Logs, charts, errors — all in one place. It should be somehow connected to where our code runs.
Where to put our containers — we package our app in Docker. We need a private "warehouse" for these images somewhere in Azure. And only our application should be able to pull from it.
Safe for passwords — all kinds of API keys, database passwords, tokens — we don't want to keep them in code or configs. We need something specialized for secrets. Access only for our application, and this safe shouldn't be exposed to the public internet.
Our private territory — we want all of this to live in an isolated network. Like our own little data center in the cloud.
Where to store data — we'll have lots of structured data: users, orders, transactions. We need a proper database that our developers know how to work with (they know SQL Server). Connection — only from inside our network, no public endpoints.
For user files — people will upload documents, photos. We need somewhere to store this. Also private, through our network. And our application should see it as a regular folder with files.
For your Terraform magic — our previous consultant said that infrastructure state shouldn't be kept on a laptop. Set up something so it's stored reliably in the cloud.

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────┐
│                  Azure VNet (10.0.0.0/16)           │
│                                                     │
│  ┌──────────────────────┐                           │
│  │  subnet-app          │                           │
│  │  10.0.1.0/24         │                           │
│  │                      │                           │
│  │  ┌────────────────┐  │                           │
│  │  │  App Service   │  │                           │
│  │  │  (Docker)      │  │                           │
│  │  │  Managed       │  │                           │
│  │  │  Identity      │  │                           │
│  │  └────────────────┘  │                           │
│  └──────────────────────┘                           │
│                                                     │
│  ┌──────────────────────────────────────────────┐   │
│  │  subnet-endpoints (10.0.2.0/24)              │   │
│  │                                              │   │
│  │  PE-ACR   PE-SQL   PE-KeyVault   PE-Storage  │   │
│  └──────────────────────────────────────────────┘   │
│                                                     │
└─────────────────────────────────────────────────────┘
         │           │           │           │
         ▼           ▼           ▼           ▼
        ACR        SQL DB    Key Vault    Storage
   (containers) (user data) (secrets)  (user files)

Monitoring: App Insights + Log Analytics (outside VNet)
```

---

## Project Structure

```
bestrong-infrastructure-azure/
│
├── providers.tf      # Terraform version, Azure provider config
├── variables.tf      # All input variables with defaults
├── outputs.tf        # Output values after deployment
│
├── app.tf            # App Service Plan, Web App, VNet integration
├── network.tf        # Virtual Network (VNet), Subnets, and NSG rules
├── acr.tf            # Container Registry + Private Endpoint
├── database.tf       # SQL Server, SQL Database + Private Endpoint
├── storage.tf        # Storage Account, File Share + Private Endpoint
├── security.tf       # Key Vault, access policies, secrets
├── monitoring.tf     # Log Analytics, App Insights, alerts, diagnostics
│
├── terraform.tfvars  # Local variable values (NOT committed to git)
├── .gitignore        # Excludes sensitive files from git
└── README.md         # This file
```

---

## File Descriptions

### `providers.tf`
Defines required Terraform version (`>= 1.5.0`) and provider versions:
- `azurerm ~> 4.0` — main Azure provider
- `random ~> 3.6` — for SQL password generation

Configures the `azurerm` provider with Key Vault soft-delete behavior and resource group deletion protection.

Also configures the **remote backend** — Terraform state is stored in Azure Blob Storage, not locally.

---

### `variables.tf`

Key variables:
- `project_name` — used in all resource names (default: `bestrong`)
- `location` — Azure region (default: `West Europe`)
- `app_service_sku` — App Service tier (default: `P1v3`)
- `sql_sku` — database tier (default: `S0`)
- `terraform_client_ip` — your local IP for Key Vault access during development

---

### `outputs.tf`
Values printed after `terraform apply`:
- Web App URL
- ACR login server (for CI/CD docker push)
- SQL Server FQDN
- Key Vault URI


---

### `network.tf`
Core networking infrastructure:

- **Resource Group** — single container for all resources (`bestrong-rg`)
- **NSG (nsg-app)** — firewall for App Service subnet: allows HTTPS (443) inbound only
- **NSG (nsg-endpoints)** — firewall for private endpoints subnet: blocks all internet traffic
- **VNet** (`10.0.0.0/16`) with two subnets:
  - `subnet-app` (`10.0.1.0/24`) — for App Service with delegation to `Microsoft.Web/serverFarms`
  - `subnet-endpoints` (`10.0.2.0/24`) — for all Private Endpoints

---

### `app.tf`
Application compute layer:

- **App Service Plan** (`P1v3`) — Premium tier, required for autoscaling
- **Linux Web App** — runs Docker container from ACR
  - `SystemAssigned` Managed Identity — authenticates to ACR, Key Vault, Storage without passwords
  - Mounts Azure File Share as `/app/uploads` inside the container
  - Reads secrets from Key Vault via `@Microsoft.KeyVault(SecretUri=...)` references
- **VNet Integration** — connects App Service to `subnet-app`
- **Autoscale** — scales from 1 to 3 instances based on CPU (scale out >70%, scale in <30%)

---

### `acr.tf`
Docker image registry:

- **Azure Container Registry** (`Premium` SKU) — required for Private Endpoints
  - `public_network_access_enabled = false` — no public access
- **Private DNS Zone** (`privatelink.azurecr.io`) — internal name resolution
- **Private Endpoint** — connects ACR to `subnet-endpoints`
- **Role Assignment** — grants App Service `AcrPull` role via Managed Identity (no passwords)

---

### `database.tf`
Relational database layer:

- **Azure SQL Server** — `public_network_access_enabled = false`
  - Password auto-generated by `random_password`, stored in Key Vault
- **Azure SQL Database** (`S0` SKU) — 10 DTU, 250 GB, suitable for production workloads
  - `prevent_destroy = true` — Terraform will refuse to delete this accidentally
- **Private DNS Zone** (`privatelink.database.windows.net`)
- **Private Endpoint** — database accessible only from within VNet

---

### `storage.tf`
User file storage:

- **Storage Account** — `public_network_access_enabled = false`, `LRS` replication
- **File Share** (`userfiles`) — 50 GB quota, mounted into App Service container
- **Private DNS Zone** (`privatelink.file.core.windows.net`)
- **Private Endpoint** — storage accessible only from within VNet

---

### `security.tf`
Secrets management:

- **`random_password`** — generates 16-character SQL admin password automatically
- **`data.azurerm_client_config`** — reads current Azure account info (tenant ID, object ID)
- **Key Vault** (`standard` SKU):
  - `soft_delete_retention_days = 90` — 90-day recovery window
  - `purge_protection_enabled = true` — prevents immediate permanent deletion
  - `network_acls` — allows only trusted Azure services + your local IP (dev only)
  - Access policy for Terraform client — full secret management
  - Access policy for Web App Managed Identity — `Get`, `List` only
- **Secrets stored in Key Vault:**
  - `sql-admin-password` — auto-generated SQL password
  - `storage-access-key` — Storage Account primary key
- **Private DNS Zone** (`privatelink.vaultcore.azure.net`)
- **Private Endpoint** — Key Vault accessible only from within VNet

---

### `monitoring.tf`
Observability stack:

- **Log Analytics Workspace** — central log storage, 30-day retention
- **Application Insights** — real-time performance monitoring, error tracking, dashboards
  - Connected to Log Analytics Workspace
- **Diagnostic Settings** — forwards platform logs to Log Analytics:
  - Web App: console logs, HTTP logs, platform events
  - Key Vault: secret access audit log
  - SQL Server: security audit events
- **Metric Alerts:**
  - HTTP 5xx errors > 10 in 5 minutes → severity 1 (Error)
  - CPU > 90% for 5 minutes → severity 1 (Error)


---

## Getting Started

### 1. Login to Azure

```bash
az login
```

### 2. Create remote state storage (one time only)

```powershell
az group create --name rg-terraform-meta --location westeurope

az storage account create `
  --name stbestrongtfstate `
  --resource-group rg-terraform-meta `
  --location westeurope `
  --sku Standard_LRS

az storage container create `
  --name tfstate `
  --account-name stbestrongtfstate
```

### 3. Create terraform.tfvars

```hcl
# terraform.tfvars — do not commit to git
terraform_client_ip = "YOUR_PUBLIC_IP"
# Check your IP at: https://ifconfig.me
```

### 4. Initialize and deploy

```powershell
terraform init
terraform plan
terraform apply
```

---

## Remote State

Terraform state is stored remotely in Azure Blob Storage:

```
Storage Account : stbestrongtfstate
Container       : tfstate
Key (file)      : bestrong.terraform.tfstate
```

This ensures:
- State is not lost if your laptop is wiped
- Team members share the same state
- State file is versioned (blob versioning enabled)

---

## CI/CD scheme
<img width="1322" height="1161" alt="Untitled Diagram-Page-1 drawio" src="https://github.com/user-attachments/assets/5866196e-5cd1-44a9-8a44-d8787b362e2d" />

---
