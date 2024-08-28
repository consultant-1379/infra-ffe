variable "deployment_id" {
  type = string
}
variable "ssh_public_key" {
  type = string
}
variable "external_network_id" {
  type = string
}
variable "networks" {
  description = "Networks for vLITP"
  type        = map(string)
  default = {
    "service"  = "192.168.0.0/16",
    "storint"  = "172.16.0.0/24",
    "internal" = "10.247.244.0/22",
    "backup"   = "172.16.8.0/22",
    "jgroups"  = "10.250.244.0/22",
    "storage"  = "172.16.16.0/22",
    "mgmt"     = "172.16.20.0/22",
    "hb1"      = "172.16.24.0/24",
    "hb2"      = "172.16.25.0/24",
    "dummy"    = "172.16.32.0/24"
  }
}
variable "networks_v6" {
  description = "Networks for vLITP"
  type        = map(string)
  default = {
    "service" = "2001:1b70:82a1:103::/64"
  }
}
variable "networks_without_gateway" {
  type    = set(string)
  default = ["hb1", "hb2", "storint", "dummy"]
}
variable "vlans" {
  type = map(string)
  default = {
    "internal" = 2000,
    "service"  = 2008,
    "jgroups"  = 2024,
    "storage"  = 2016,
    "backup"   = 2032,
    "hb1"      = 2101,
    "hb2"      = 2102
  }
}

variable "router_ports" {
  type    = set(string)
  default = ["mgmt", "service", "storage"]

}

variable "ipxe_url" {
  type    = string
  default = "http://ieatreposvr01.athtem.eei.ericsson.se/vlitp/ipxe_uefi.iso"
}
