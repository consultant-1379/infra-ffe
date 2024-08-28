terraform {
  required_version = ">= 0.14.0"
  required_providers {
    openstack = {
      source                = "terraform-provider-openstack/openstack"
      version               = "~> 1.54.1"
      configuration_aliases = [openstack.base_project]
    }
  }

}

locals {
  ssh_key = "${var.deployment_id}_key"
}

# SSH Key
resource "openstack_compute_keypair_v2" "ssh_key" {
  name       = local.ssh_key
  public_key = var.ssh_public_key
}

# Networks
resource "openstack_networking_network_v2" "network" {
  name                  = "${var.deployment_id}_${each.key}"
  admin_state_up        = "true"
  port_security_enabled = false
  external              = false
  shared                = false
  for_each              = var.networks
  tags                  = [var.deployment_id, "${var.deployment_id}_${each.key}"]
}

resource "openstack_networking_subnet_v2" "subnet" {
  name       = "${var.deployment_id}_${each.key}_ipv4"
  for_each   = openstack_networking_network_v2.network
  network_id = each.value.id
  cidr       = var.networks[each.key]
  ip_version = 4
  # set gateway_ip to null if the network is in var.networks_without_gateway else get the gateway IP address (router port address)
  gateway_ip = contains(var.networks_without_gateway, each.key) ? null : cidrhost(lookup(var.networks, each.key), -2)
  #set no_gateway to "true" if the network is in var.networks_without_gateway else null
  no_gateway  = contains(var.networks_without_gateway, each.key) ? "true" : null
  enable_dhcp = false
}


resource "openstack_networking_subnet_v2" "subnet_v6" {
  name       = "${var.deployment_id}_service_ipv6"
  network_id = openstack_networking_network_v2.network["service"].id
  cidr       = var.networks_v6["service"]
  ip_version = 6
  # set gateway_ip to null if the network is in var.networks_without_gateway else get the gateway IP address (router port address)
  gateway_ip = cidrhost(var.networks_v6["service"], -2)
  enable_dhcp = false
}


# Router
resource "openstack_networking_router_v2" "router" {
  name           = "${var.deployment_id}_router"
  admin_state_up = true

}

resource "openstack_networking_port_v2" "router_port" {
  name           = "${var.deployment_id}_router_${each.key}_port"
  for_each       = var.router_ports
  network_id     = openstack_networking_network_v2.network[each.key].id
  admin_state_up = "true"
  fixed_ip {
    subnet_id = openstack_networking_subnet_v2.subnet[each.key].id
    # Use last usable IP address (i.e. not the broadcast address)
    ip_address = cidrhost(lookup(var.networks, each.key), -2)
  }
  tags = each.key == "storage" ? ["edp", "storage", "${var.deployment_id}_router_storage"] : []
}

resource "openstack_networking_router_interface_v2" "router_interface" {
  router_id = openstack_networking_router_v2.router.id
  for_each  = openstack_networking_port_v2.router_port
  port_id   = each.value.id
}

# Outputs
output "networks" {
  value = { for net, cidr in var.networks : net => { "network_id" = openstack_networking_network_v2.network[net].id, "subnet_id" = openstack_networking_subnet_v2.subnet[net].id, "cidr" = cidr } }

}
output "vlans" {
  value = var.vlans
}

output "service_ipv6_subnet" {
  value = openstack_networking_subnet_v2.subnet_v6.id
}