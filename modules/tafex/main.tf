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

resource "openstack_networking_port_v2" "tafex_port" {
  name                  = "${var.deployment_id}_tafex_port"
  network_id            = var.northbound_network
  admin_state_up        = "true"
  port_security_enabled = "false"
  fixed_ip {
    subnet_id  = var.northbound_ipv4_subnet
    ip_address = var.tafex_ipv4
  }
  fixed_ip {
    subnet_id  = var.northbound_ipv6_subnet
    ip_address = var.tafex_ipv6
  }

}

data "openstack_blockstorage_volume_v3" "tafex_source_volume" {
  provider = openstack.base_project
  name     = var.base_volume
}
resource "openstack_blockstorage_volume_v3" "tafex_root_volume" {
  name          = "${var.deployment_id}_tafex_root_volume"
  size          = 64
  source_vol_id = data.openstack_blockstorage_volume_v3.tafex_source_volume.id
}
resource "openstack_blockstorage_volume_v3" "tafex_home_volume" {
  name = "${var.deployment_id}_tafex_home_volume"
  size = 200
}
resource "openstack_compute_instance_v2" "tafex" {
  name      = "${var.deployment_id}_tafex"
  flavor_id = data.openstack_compute_flavor_v2.flavor.id
  key_pair  = var.ssh_key
  block_device {
    uuid                  = openstack_blockstorage_volume_v3.tafex_root_volume.id
    source_type           = "volume"
    boot_index            = 0
    destination_type      = "volume"
    delete_on_termination = false
  }
  block_device {
    uuid                  = openstack_blockstorage_volume_v3.tafex_home_volume.id
    source_type           = "volume"
    boot_index            = 1
    destination_type      = "volume"
    delete_on_termination = false
  }
  config_drive = true
  user_data = <<EOF
#cloud-config
hostname: tafexem1
password: $6$rounds=250000$FwSLoJ/xeE3L9bHN$V10MtsD6pJq09mwKSKhfHAz5YBST9KBFz4V4/NDZEXlsSUhLoc7SIuQ5EEGkveOmx.lkKVck489uUDlnJm6sC1
chpasswd:
  expire: False
# cinder volumes presented to the VM as /dev/disk/by-id/virtio-<first 20 characters of volume ID>
fs_setup:
  - filesystem: ext4
    device: /dev/disk/by-id/virtio-${substr(openstack_blockstorage_volume_v3.tafex_home_volume.id, 0, 20)}
    partition: none
mounts:
 - [/dev/disk/by-id/virtio-${substr(openstack_blockstorage_volume_v3.tafex_home_volume.id, 0, 20)},/home/, ext4, defaults, "0", "0"]
swap:
  filename: /swapfile
  size: 3G
  maxsize: 3G
write_files:
- path: /etc/systemd/resolved.conf
  content: |
    [Resolve]
    DNS=192.168.0.1
    Domains=vts.com athtem.eei.ericsson.se
- path: /etc/netplan/99-netplan.yaml
  encoding: base64
  permissions: "0600"
  content: ${base64encode(file(join("/", [path.module, "99-netplan.yaml"])))}
runcmd:
- rm -f /etc/netplan/50-cloud-init.yaml
- netplan apply
- systemctl daemon-reload
- systemctl restart systemd-resolved
- systemctl restart te_full.service
    EOF

  network {
    port = openstack_networking_port_v2.tafex_port.id

  }
}
