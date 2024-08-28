terraform {
  required_version = ">= 0.14.0"
  required_providers {
    openstack = {
      source                = "registry.terraform.io/terraform-provider-openstack/openstack"
      version               = "~> 1.54.1"
      configuration_aliases = [openstack.base_project]
    }
  }
}

data "openstack_compute_flavor_v2" "flavor" {
  name = var.flavor
}

resource "openstack_networking_port_v2" "netsim_port" {
  name                  = "${var.deployment_id}_netsim_port"
  network_id            = var.northbound_network
  admin_state_up        = "true"
  port_security_enabled = "false"
  fixed_ip {
    subnet_id  = var.northbound_ipv4_subnet
    ip_address = "192.168.0.2"
  }
  fixed_ip {
    subnet_id  = var.northbound_ipv6_subnet
    ip_address = "2001:1b70:82a1:103::2"
  }

}

data "openstack_blockstorage_volume_v3" "netsim_source_volume" {
  provider = openstack.base_project
  name     = var.base_volume
}
resource "openstack_blockstorage_volume_v3" "netsim_root_volume" {
  name          = "${var.deployment_id}_netsim_root_volume"
  size          = 64
  source_vol_id = data.openstack_blockstorage_volume_v3.netsim_source_volume.id
}
resource "openstack_compute_instance_v2" "netsim" {
  name      = "${var.deployment_id}_netsim"
  flavor_id = data.openstack_compute_flavor_v2.flavor.id
  key_pair  = var.ssh_key
  block_device {
    uuid                  = openstack_blockstorage_volume_v3.netsim_root_volume.id
    source_type           = "volume"
    boot_index            = 0
    destination_type      = "volume"
    delete_on_termination = false
  }
  user_data = <<EOF
#cloud-config
disable_root: false
ssh_pw_auth: true
password: 12shroot
chpasswd:
  expire: False
EOF
  network {
    port = openstack_networking_port_v2.netsim_port.id

  }

}
