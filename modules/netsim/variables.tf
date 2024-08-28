variable "deployment_id" {
  description = "FFE deployment id e.g. ieatenmc17b03"
  type        = string
}
variable "flavor" {
  type    = string
  default = "vENM-master-netsim"
}
variable "image" {
  type    = string
  default = "netsim_base"
}
variable "ssh_key" {
  type        = string
  description = "SSH Key used to access netsim VM"
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
variable "base_volume" {
  type        = string
  description = "The name of the volume to clone from"
  default     = "netsim_base_root_volume"
}
