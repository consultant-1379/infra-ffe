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
  peer_name       = format("peer%0.2d", var.peer_num + 1)
  peer_networks   = var.node_type == "db_node" ? var.db_networks : var.svc_networks
  mac_index_start = var.peer_num + 4
}
data "openstack_compute_flavor_v2" "flavor" {
  name = var.flavor
}
resource "openstack_networking_port_v2" "peer_ports" {
  name           = "${var.deployment_id}_${local.peer_name}_${each.key}"
  for_each       = local.peer_networks
  network_id     = var.networks[each.key].network_id
  admin_state_up = "true"
  tags           = ["peer", var.deployment_id, each.key]
  mac_address    = format("${var.base_mac}:%0.2x:01", local.mac_index_start)
  no_fixed_ip    = each.key == "internal" ? null : true
  dynamic "fixed_ip" {
    for_each = each.key == "internal" ? [1] : []
    content {
      subnet_id = var.networks[each.key].subnet_id
      # skip to 172.16.17.1 = 172.16.16.0 + 256 + 1 + peer_num (starts at 0)
      ip_address = cidrhost(var.networks[each.key].cidr, 257 + var.peer_num)
    }
  }
}
resource "openstack_networking_trunk_v2" "peer_trunk" {
  name           = "${var.deployment_id}_${local.peer_name}_eth0"
  port_id        = openstack_networking_port_v2.peer_ports["internal"].id
  admin_state_up = true
  #create a sub_port for each network except the network used by the parent port
  dynamic "sub_port" {
    # sub_port.key in the content refers to the current item in the list
    for_each = [for n in local.peer_networks : n if n != "internal"]
    content {
      port_id           = openstack_networking_port_v2.peer_ports[sub_port.value].id
      segmentation_id   = var.vlans[sub_port.value]
      segmentation_type = "vlan"
    }
  }
}
resource "openstack_networking_port_v2" "peer_dummy_ports" {
  name           = "${var.deployment_id}_${local.peer_name}_eth${count.index + 1}"
  count          = 3
  network_id     = var.networks["dummy"].network_id
  admin_state_up = "false"

  mac_address = format("${var.base_mac}:%0.2x:%0.2d", local.mac_index_start, count.index + 2)
  tags        = ["peer", var.deployment_id, "dummy"]
  # no_fixed_ip = true
  fixed_ip {
    subnet_id  = var.networks["dummy"].subnet_id
    ip_address = cidrhost(var.networks["dummy"].cidr, var.dummy_ip_start + (var.peer_num * 3) + count.index)
  }
}
