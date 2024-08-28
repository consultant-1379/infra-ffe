variable "deployment_id" {
  description = "FFE deployment id e.g. ieatenmc17b03"
  type        = string
}
variable "flavor" {
  type    = string
  default = "vENM-master-tafexem"
}
variable "image" {
  type    = string
  default = "tafexem_base"
}
variable "ssh_key" {
  type        = string
  description = "SSH Key used to access TAF Executor VM"
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
variable "tafex_ipv4" {
  type        = string
  description = "IPv4 address for the tafex VM"
  default     = "192.168.0.197"
}
variable "tafex_ipv6" {
  type        = string
  description = "IPv6 address for the tafex VM"
  default     = "2001:1b70:82a1:103::c5"
}
variable "base_volume" {
  type        = string
  description = "The name of the volume to clone from"
  default     = "tafex_base_root_volume"
}
