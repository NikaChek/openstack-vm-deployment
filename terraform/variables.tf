variable "external_network_id" {
  description = "ID of the external network for floating IPs"
  type        = string
}

variable "keypair_name" {
  description = "Name of the SSH keypair to inject into the instance"
  type        = string
}