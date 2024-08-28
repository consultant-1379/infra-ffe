variable "deployment_id" {
  description = "FFE deployment id e.g. ieatenmc17b03"
  type        = string
}
variable "external_network_name" {
  description = "The external network to which the gateway VM is connected"
  type        = string
}
variable "northbound_network" {
  type        = string
  description = "Northbound network for vENM"
}
variable "northbound_ipv4_subnet" {
  type = string
}
variable "northbound_ipv6_subnet" {
  type = string
}
variable "flavor" {
  type    = string
  default = "FFE_gateway_flavor"
}
variable "image" {
  type    = string
  default = "gateway_base"
}
variable "ssh_key" {
  type        = string
  description = "Name of the SSH Keypair"
}
variable "ssh_public_key" {
  type        = string
  description = "SSH Key used to access gateway VM"
}
variable "gateway_external_ip" {
  type        = string
  description = "Public IPv4 address for the gateway VM"
}
variable "gateway_external_ipv6" {
  type        = string
  description = "Public IPv4 address for the gateway VM"
}
variable "base_volume" {
  type        = string
  description = "The name of the base gateway volume to clone."
  default     = "gateway_base_root_volume"
}
