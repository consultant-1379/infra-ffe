variable "deployment_id" {
  type = string
}
variable "networks" {
  type = map(any)

}
variable "open_ports" {
  description = "Ports to open for the gateway"
  type        = map(any)
  default = {
    "icmp"             = { "protocol" : "icmp" }
    "ssh"              = { "min" : 22, "max" : 22 },
    "netsim_ssh"       = { "min" : 2202, "max" : 2202 },
    "netsim_telnet"    = { "min" : 2302, "max" : 2302 },
    "netsim_syslog"    = { "min" : 514, "max" : 514 },
    "tafexem1_jenkins" = { "min" : 8080, "max" : 8080 },
    "seleniumhub_vnc"  = { "min" : 5901, "max" : 5904 },
    "http_ui"          = { "min" : 80, "max" : 80 },
    "https_ui"         = { "min" : 443, "max" : 443 }
  }
}
variable "external_network_id" {
  type = string
}
variable "external_subnet_ipv4_id" {
  type = string
}
variable "router_ports" {
  type    = set(string)
  default = ["mgmt", "service", "storage"]
}
variable "gateway_ports" {
  type    = map(string)
  default = { "mgmt" : "00:01:00:00:00:01", "service" : "00:01:00:00:00:02", "storage" : "00:01:00:00:00:03", "storint" : "00:01:00:00:00:04" }
}
variable "public_ip" {
  type = string
}
variable "edp_volume_size" {
  type    = number
  default = 104
}
variable "flavor" {
  type = string
}
variable "ssh_public_key" {
  type        = string
  description = "SSH Key used to access gateway VM"
}
variable "image" {
  type    = string
  default = "vlitp_gateway_base"
}
