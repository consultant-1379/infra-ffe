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

resource "openstack_networking_port_v2" "seleniumhub_port" {
  name                  = "${var.deployment_id}_seleniumhub_port"
  network_id            = var.northbound_network
  admin_state_up        = "true"
  port_security_enabled = "false"
  fixed_ip {
    subnet_id  = var.northbound_ipv4_subnet
    ip_address = "192.168.0.231"
  }
  fixed_ip {
    subnet_id  = var.northbound_ipv6_subnet
    ip_address = "2001:1b70:82a1:103::e7"
  }

}
data "openstack_blockstorage_volume_v3" "seleniumhub_source_volume" {
  provider = openstack.base_project
  name     = var.base_volume
}
resource "openstack_blockstorage_volume_v3" "seleniumhub_root_volume" {
  name          = "${var.deployment_id}_seleniumhub_root_volume"
  size          = 40
  source_vol_id = data.openstack_blockstorage_volume_v3.seleniumhub_source_volume.id
}
resource "openstack_compute_instance_v2" "seleniumhub" {
  name      = "${var.deployment_id}_seleniumhub"
  flavor_id = data.openstack_compute_flavor_v2.flavor.id
  key_pair  = var.ssh_key
  block_device {
    uuid                  = openstack_blockstorage_volume_v3.seleniumhub_root_volume.id
    source_type           = "volume"
    boot_index            = 0
    destination_type      = "volume"
    delete_on_termination = false
  }
  config_drive = true
  user_data = <<EOF
  #cloud-config
  hostname: selenium-hub
  password: $6$rounds=250000$zVYoLcsbfZIar4NU$GkoQ0KMK.wYZyaydVuTvWXCwVWi1dwpsK1LF9pQKt30wp04BN82f9nulz53YG50meXE7hZZoda3Ofz0.FRTug1
  chpasswd:
    expire: False
  swap:
    filename: /swapfile
    size: 1G
    maxsize: 1G
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
    port = openstack_networking_port_v2.seleniumhub_port.id

  }

}
