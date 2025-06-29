variable "resource_group_location" {
  type        = string
  default     = "eastus"
  description = "Location of the resource group."
}

variable "username" {
  type        = string
  description = "The username for the local account that will be created on the new VM."
  default     = "azureadmin"
}

variable "vm_count" {
  description = "Number of VMs to create"
  type        = number
  default     = 5 # Default to 3 VMs if not specified
}

variable "azure_username" {
  type        = string
  description = "The username for the local account that will be created on the new VM."
  default     = "azureadmin"
}

variable "azure_password" {
  type        = string
  description = "The username for the local account that will be created on the new VM."

}