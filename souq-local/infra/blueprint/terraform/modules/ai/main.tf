# DORMANT — Azure OpenAI / AI Foundry module
# Enable only when product requires NL search or recommendations.
# No application dependency today.

variable "name_prefix" { type = string }
variable "location" { type = string }
variable "resource_group_name" { type = string }
variable "tags" { type = map(string); default = {} }

# Placeholder — actual OpenAI account requires quota approval per region
output "ai_status" {
  value = "dormant — enable module_flags.ai and add azurerm_cognitive_account when approved"
}
