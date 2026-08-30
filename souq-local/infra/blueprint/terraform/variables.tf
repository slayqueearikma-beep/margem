# =============================================================================
# MarGem Enterprise Blueprint — Root Variables
# blueprint_enabled = false (default) → ZERO resources provisioned
# =============================================================================

variable "subscription_id" {
  description = "Azure subscription ID. Isolated from infra/terraform state."
  type        = string
  default     = ""
}

variable "blueprint_enabled" {
  description = "MASTER SWITCH. Must be true to create any blueprint resource. Default false = dormant."
  type        = bool
  default     = false
}

variable "environment_name" {
  description = "dev | staging | production"
  type        = string
  default     = "staging"

  validation {
    condition     = contains(["dev", "staging", "production"], var.environment_name)
    error_message = "environment_name must be dev, staging, or production."
  }
}

variable "activation_phase" {
  description = "Migration phase label for tagging (0-5). Informational only."
  type        = string
  default     = "0"
}

variable "location" {
  description = "Primary Azure region"
  type        = string
  default     = "westeurope"
}

variable "dr_location" {
  description = "Disaster recovery region"
  type        = string
  default     = "francecentral"
}

variable "name_prefix" {
  description = "Resource name prefix"
  type        = string
  default     = "margem"
}

variable "vnet_address_space" {
  type    = list(string)
  default = ["10.0.0.0/16"]
}

# Per-module feature flags — all false by default
variable "module_flags" {
  description = "Enable individual blueprint modules. Ignored when blueprint_enabled=false."
  type = object({
    networking    = optional(bool, false)
    keyvault      = optional(bool, false)
    postgresql    = optional(bool, false)
    storage       = optional(bool, false)
    monitoring    = optional(bool, false)
    security      = optional(bool, false)
    aks           = optional(bool, false)
    appservice    = optional(bool, false) # Bridge from Container Apps
    apim          = optional(bool, false)
    frontdoor     = optional(bool, false)
    redis         = optional(bool, false)
    servicebus    = optional(bool, false)
    messaging     = optional(bool, false) # Event Grid + Event Hubs
    search        = optional(bool, false)
    ai            = optional(bool, false)
    ddos_protection = optional(bool, false)
    firewall      = optional(bool, false)
    multi_region  = optional(bool, false)
  })
  default = {}
}

variable "postgres_admin_login" {
  type      = string
  default   = "margemadmin"
  sensitive = true
}

variable "postgres_admin_password" {
  type      = string
  default   = ""
  sensitive = true
}

variable "domain_name" {
  description = "Public API domain (e.g. api.margem.ma)"
  type        = string
  default     = "api.margem.ma"
}

variable "common_tags" {
  type = map(string)
  default = {
    project    = "margem"
    managed_by = "terraform-blueprint"
    status     = "dormant"
  }
}
