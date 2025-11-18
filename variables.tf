variable "subscription_id" {
  description = "Azure subscription id to deploy resources into."
  type        = string
}

variable "tenant_id" {
  description = "Azure tenant id (optional). If empty, provider will try env var or azure cli auth."
  type        = string
  default     = ""
}

variable "client_id" {
  description = "Service principal client id (optional). Prefer environment var ARM_CLIENT_ID."
  type        = string
  default     = ""
}

variable "client_secret" {
  description = "Service principal client secret (sensitive). Prefer environment var ARM_CLIENT_SECRET."
  type        = string
  default     = ""
  sensitive   = true
}
# variables.tf
variable "ssh_pub_key_path" {
  description = "Path to SSH public key file"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

variable "zone2" {
  description = "List of availability zones for the VM. Use a single element for one zone or multiple for multi-zone placement. Example: [\"2\"] or [\"2\", \"3\"]"
  type        = list(string)
  default     = ["2"]
}
variable "zone3" {
  description = "List of availability zones for the VM. Use a single element for one zone or multiple for multi-zone placement. Example: [\"2\"] or [\"2\", \"3\"]"
  type        = list(string)
  default     = ["3"]
}

variable "mysql_admin_password" {
  description = "Admin password for MySQL (or shared secret used by other resources)"
  type        = string
  sensitive   = true
}
