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
//NAS

data "openstack_compute_flavor_v2" "flavor" {
  name = var.flavor
}

data "openstack_images_image_v2" "image" {
  name = var.image
}

resource "openstack_networking_port_v2" "nas_ports" {
  name           = "${var.deployment_id}_nas1_${each.key}"
  for_each       = var.nas_ports
  network_id     = var.networks[each.key].network_id
  admin_state_up = "true"
  fixed_ip {
    subnet_id  = var.networks[each.key].subnet_id
    ip_address = lookup(each.value, "ip")
  }
  mac_address = lookup(each.value, "mac")
  tags        = ["nas1", var.deployment_id, each.key]
}
resource "openstack_blockstorage_volume_v3" "nas_data_volume" {
  name = "${var.deployment_id}_nas_data"
  size = var.nas_data_volume_size
}

resource "openstack_compute_instance_v2" "nas" {
  name      = "${var.deployment_id}_nas"
  flavor_id = data.openstack_compute_flavor_v2.flavor.id
  image_id  = data.openstack_images_image_v2.image.id
  block_device {
    uuid                  = data.openstack_images_image_v2.image.id
    source_type           = "image"
    destination_type      = "local"
    boot_index            = 0
    delete_on_termination = true
  }
  block_device {
      uuid                  = openstack_blockstorage_volume_v3.nas_data_volume.id
      source_type           = "volume"
      boot_index            = 1
      destination_type      = "volume"
      delete_on_termination = false
  }
  network {
      port = openstack_networking_port_v2.nas_ports["storint"].id
  }
  network {
      port = openstack_networking_port_v2.nas_ports["storage"].id
  }
}
