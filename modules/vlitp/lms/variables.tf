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

variable "lms_ports" {
  type    = set(string)
  default = ["backup", "service", "storage", "internal"]
}
variable "lms_dummy_base_mac" {
  type    = string
  default = "00:00:00:00:01"
}
variable "lms_boot_volume_size" {
  type = number
  # increased from 1228 to prevent changes in subsequent terraform runs
  default = 1232
}
variable "flavor" {
  type = string
}
