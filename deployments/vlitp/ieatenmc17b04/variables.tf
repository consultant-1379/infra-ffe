variable "project" {
  type = string
}
variable "base_project" {
  type = string
}
variable "deployment_id" {
  type = string
}
variable "external_network" {
  type = string
}
variable "ssh_public_key" {
  type = string
}
variable "public_ip" {
  type = string
}
variable "db_node_count" {
  type    = number
  default = 3
}
variable "svc_node_count" {
  type    = number
  default = 3
}
variable "netsim_base_volume" {
  type = string
}
variable "seleniumhub_base_volume" {
  type = string
}
variable "tafex_base_volume" {
  type = string
}