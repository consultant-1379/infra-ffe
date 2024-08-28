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

//LMS
data "openstack_compute_flavor_v2" "flavor" {
  name = var.flavor
}


resource "openstack_networking_port_v2" "lms_ports" {
  name           = "${var.deployment_id}_lms_${each.key}"
  for_each       = var.lms_ports
  network_id     = var.networks[each.key].network_id
  admin_state_up = "true"
  mac_address    = format("${var.lms_dummy_base_mac}:%0.2x", 1)
  tags           = ["vlms1", var.deployment_id, each.key]
  no_fixed_ip    = each.key == "service" ? null : true
  dynamic "fixed_ip" {
    for_each = each.key == "service" ? [1] : []
    content {
      subnet_id  = var.networks[each.key].subnet_id
      ip_address = cidrhost(var.networks[each.key].cidr, 3)
    }
  }
}

resource "openstack_networking_trunk_v2" "lms_trunk" {
  name           = "${var.deployment_id}_lms_eth0"
  admin_state_up = true
  port_id        = openstack_networking_port_v2.lms_ports["service"].id
  #create a sub_port for each network except the network used by the parent port
  dynamic "sub_port" {
    # sub_port.key in the content refers to the current item in the list
    for_each = [for n in var.lms_ports : n if n != "service"]
    content {
      port_id           = openstack_networking_port_v2.lms_ports[sub_port.value].id
      segmentation_id   = var.vlans[sub_port.value]
      segmentation_type = "vlan"
    }
  }
}

resource "openstack_networking_port_v2" "lms_dummy_ports" {
  name           = "${var.deployment_id}_lms_eth${count.index + 1}"
  count          = 3
  network_id     = var.networks["dummy"].network_id
  admin_state_up = "true"
  mac_address    = format("${var.lms_dummy_base_mac}:%0.2x", count.index + 2)
  tags           = ["vlms1", var.deployment_id, "dummy"]
  fixed_ip {
    subnet_id  = var.networks["dummy"].subnet_id
    ip_address = cidrhost(var.networks["dummy"].cidr, count.index + 3)
  }

}

resource "openstack_blockstorage_volume_v3" "lms_boot" {
  name        = "${var.deployment_id}_lms_boot"
  size        = var.lms_boot_volume_size
  description = jsonencode({ "deployment" : var.deployment_id, "server" : "vlms1", "type" : "preprov" })
}
