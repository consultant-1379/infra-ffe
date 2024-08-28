variable "deployment_id" {
  type = string
}
# variable to receive the networks map from the vlitp-common module
variable "networks" {
  description = "Networks for vLITP"
  type        = map(any)
}
# variable to receive the vlans map from the vlitp-common module
variable "vlans" {
  type = map(string)
}
variable "db_networks" {
  type    = set(string)
  default = ["internal", "jgroups", "storage", "backup", "hb1", "hb2"]
}
variable "svc_networks" {
  type    = set(string)
  default = ["internal", "service", "jgroups", "storage", "backup", "hb1", "hb2"]
}
variable "base_mac" {
  type    = string
  default = "00:00:00:00"
}
variable "peer_num" {
  type = number
}
variable "node_type" {
  type = string
}
variable "dummy_ip_start" {
  type    = number
  default = 10
}
variable "flavor" {
  type = string
}
