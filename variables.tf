# GLOBAL PROJECT SETTINGS
variable "project_name" {
  description = "The name of the project used as a prefix for all resource names"
  type        = string
  default     = "bestrong"
}

variable "location" {
  description = "The Azure region where all resources will be deployed"
  type        = string
  default     = "West Europe"
}

variable "terraform_client_ip" {
  description = "Your public IP for Key Vault access during terraform apply"
  type        = string
}

# NETWORKING
variable "vnet_address_space" {
  description = "The CIDR block for the Virtual Network (VNet)"
  type        = string
  default     = "10.0.0.0/16"
}

variable "subnet_app_prefix" {
  description = "The CIDR block for the application integration subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "subnet_endpoints_prefix" {
  description = "The CIDR block for the Private Endpoints subnet"
  type        = string
  default     = "10.0.2.0/24"
}

# APP SERVICE (COMPUTE)
variable "app_service_sku" {
  description = "The SKU for the App Service Plan (e.g., P1v3 supports autoscaling)"
  type        = string
  default     = "P1v3"
}

variable "app_port" {
  description = "The port number that the Docker container listens on"
  type        = number
  default     = 8080
}

variable "docker_image_name" {
  description = "The Docker image tag name for the Linux Web App"
  type        = string
  default     = "bestrong-backend:latest"
}

# DATABASE (AZURE SQL)
variable "sql_admin_login" {
  description = "The administrator login username for the Azure SQL Server"
  type        = string
  default     = "sqladmin"
}

variable "sql_sku" {
  description = "The SKU for the SQL Database (e.g., S0 provides 10 DTUs and 250 GB)"
  type        = string
  default     = "S0"
}

# STORAGE
variable "storage_share_quota_gb" {
  description = "The maximum storage capacity for the Azure File Share in gigabytes"
  type        = number
  default     = 50
}

variable "storage_replication_type" {
  description = "The data replication strategy for the Storage Account (e.g., LRS, GRS)"
  type        = string
  default     = "LRS"
}

# SECURITY (KEY VAULT)
variable "kv_soft_delete_retention_days" {
  description = "The number of days that soft-deleted secrets are retained (min 7, max 90)"
  type        = number
  default     = 90
}

# MONITORING
variable "log_retention_days" {
  description = "The data retention period in days for the Log Analytics Workspace"
  type        = number
  default     = 30
}

variable "diagnostic_setting_names" {
  type        = map(string)
  description = "Назви для налаштувань діагностики"
  default = {
    web_app = "ds-web-app-logs"
    kv      = "ds-kv-logs"
    sql     = "ds-sql-logs"
  }
}

variable "alert_cpu_threshold" {
  type        = number
  description = "Порог спрацьовування алерту по CPU (у %)"
  default     = 90
}

variable "alert_http_5xx_threshold" {
  type        = number
  description = "Кількість 5xx помилок, після якої тригериться алерт"
  default     = 10
}

variable "alert_evaluation_window" {
  type        = string
  description = "Вікно спостереження для алертів"
  default     = "PT5M"
}
