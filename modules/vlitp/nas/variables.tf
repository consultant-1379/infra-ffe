variable "deployment_id" {
  type = string
}
variable "networks" {
  type = map(any)
}
variable "nas_ports" {
  type    = map(any)
  default = { "storage" : { "mac" : "00:00:00:16:01:01", "ip" : "172.16.16.102" }, "storint" : { "mac" : "00:00:00:AC:05:01", "ip" : "172.16.0.2" } }
}
variable "nas_data_volume_size" {
  type    = number
  default = 3000
}
variable "flavor" {
  type = string
}
variable "image" {
  type    = string
  default = "vlitp_va_base"
}
