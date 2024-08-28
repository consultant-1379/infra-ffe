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


# Lookup data from external resources
data "openstack_compute_flavor_v2" "flavor" {
  name = var.flavor
}

data "openstack_networking_network_v2" "external" {
  name = var.external_network_name
}
data "openstack_networking_subnet_v2" "external_ipv4" {
  network_id = data.openstack_networking_network_v2.external.id
  ip_version = 4
}
data "openstack_networking_subnet_v2" "external_ipv6" {
  network_id = data.openstack_networking_network_v2.external.id
  ip_version = 6
}

resource "openstack_networking_port_v2" "gateway_port" {
  name                  = "${var.deployment_id}_gateway_port"
  network_id            = var.northbound_network
  admin_state_up        = "true"
  port_security_enabled = "false"
  fixed_ip {
    subnet_id  = var.northbound_ipv4_subnet
    ip_address = "192.168.0.1"
  }
  fixed_ip {
    subnet_id  = var.northbound_ipv6_subnet
    ip_address = "2001:1b70:82a1:103::1"
  }

}
resource "openstack_networking_port_v2" "gateway_external_port" {
  name               = "${var.deployment_id}_gateway_external_port"
  network_id         = data.openstack_networking_network_v2.external.id
  admin_state_up     = "true"
  security_group_ids = [openstack_networking_secgroup_v2.infra_ffl_sg.id]
  fixed_ip {
    subnet_id  = data.openstack_networking_subnet_v2.external_ipv4.id
    ip_address = var.gateway_external_ip
  }
  fixed_ip {
    subnet_id  = data.openstack_networking_subnet_v2.external_ipv6.id
    ip_address = var.gateway_external_ipv6
  }

}

resource "openstack_networking_secgroup_v2" "infra_ffl_sg" {
  name = "${var.deployment_id}_security_group"
}
resource "openstack_networking_secgroup_rule_v2" "ssh" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.infra_ffl_sg.id
}

resource "openstack_networking_secgroup_rule_v2" "icmp" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "icmp"
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.infra_ffl_sg.id
}
resource "openstack_networking_secgroup_rule_v2" "netsim_ssh" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 2202
  port_range_max    = 2202
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.infra_ffl_sg.id
}
resource "openstack_networking_secgroup_rule_v2" "netsim_telnet" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 2302
  port_range_max    = 2302
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.infra_ffl_sg.id
}
resource "openstack_networking_secgroup_rule_v2" "netsim_syslog" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 514
  port_range_max    = 514
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.infra_ffl_sg.id
}
resource "openstack_networking_secgroup_rule_v2" "emp_ssh" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 2203
  port_range_max    = 2203
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.infra_ffl_sg.id
}
resource "openstack_networking_secgroup_rule_v2" "tafexem1_jenkins" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 8080
  port_range_max    = 8080
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.infra_ffl_sg.id
}
resource "openstack_networking_secgroup_rule_v2" "seleniumhub_vnc" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 5901
  port_range_max    = 5904
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.infra_ffl_sg.id
}
resource "openstack_networking_secgroup_rule_v2" "http_ui" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 80
  port_range_max    = 80
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.infra_ffl_sg.id
}
resource "openstack_networking_secgroup_rule_v2" "https_ui" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 443
  port_range_max    = 443
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.infra_ffl_sg.id
}
resource "openstack_networking_secgroup_rule_v2" "ssh_v6" {
  direction         = "ingress"
  ethertype         = "IPv6"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = "::/0"
  security_group_id = openstack_networking_secgroup_v2.infra_ffl_sg.id
}

resource "openstack_networking_secgroup_rule_v2" "icmp_v6" {
  direction         = "ingress"
  ethertype         = "IPv6"
  protocol          = "ipv6-icmp"
  remote_ip_prefix  = "::/0"
  security_group_id = openstack_networking_secgroup_v2.infra_ffl_sg.id
}
resource "openstack_networking_secgroup_rule_v2" "netsim_ssh_v6" {
  direction         = "ingress"
  ethertype         = "IPv6"
  protocol          = "tcp"
  port_range_min    = 2202
  port_range_max    = 2202
  remote_ip_prefix  = "::/0"
  security_group_id = openstack_networking_secgroup_v2.infra_ffl_sg.id
}
resource "openstack_networking_secgroup_rule_v2" "netsim_telnet_v6" {
  direction         = "ingress"
  ethertype         = "IPv6"
  protocol          = "tcp"
  port_range_min    = 2302
  port_range_max    = 2302
  remote_ip_prefix  = "::/0"
  security_group_id = openstack_networking_secgroup_v2.infra_ffl_sg.id
}
resource "openstack_networking_secgroup_rule_v2" "netsim_syslog_v6" {
  direction         = "ingress"
  ethertype         = "IPv6"
  protocol          = "tcp"
  port_range_min    = 514
  port_range_max    = 514
  remote_ip_prefix  = "::/0"
  security_group_id = openstack_networking_secgroup_v2.infra_ffl_sg.id
}
resource "openstack_networking_secgroup_rule_v2" "emp_ssh_v6" {
  direction         = "ingress"
  ethertype         = "IPv6"
  protocol          = "tcp"
  port_range_min    = 2203
  port_range_max    = 2203
  remote_ip_prefix  = "::/0"
  security_group_id = openstack_networking_secgroup_v2.infra_ffl_sg.id
}
resource "openstack_networking_secgroup_rule_v2" "tafexem1_jenkins_v6" {
  direction         = "ingress"
  ethertype         = "IPv6"
  protocol          = "tcp"
  port_range_min    = 8080
  port_range_max    = 8080
  remote_ip_prefix  = "::/0"
  security_group_id = openstack_networking_secgroup_v2.infra_ffl_sg.id
}
resource "openstack_networking_secgroup_rule_v2" "seleniumhub_vnc_v6" {
  direction         = "ingress"
  ethertype         = "IPv6"
  protocol          = "tcp"
  port_range_min    = 5901
  port_range_max    = 5904
  remote_ip_prefix  = "::/0"
  security_group_id = openstack_networking_secgroup_v2.infra_ffl_sg.id
}
resource "openstack_networking_secgroup_rule_v2" "http_ui_v6" {
  direction         = "ingress"
  ethertype         = "IPv6"
  protocol          = "tcp"
  port_range_min    = 80
  port_range_max    = 80
  remote_ip_prefix  = "::/0"
  security_group_id = openstack_networking_secgroup_v2.infra_ffl_sg.id
}
resource "openstack_networking_secgroup_rule_v2" "https_ui_v6" {
  direction         = "ingress"
  ethertype         = "IPv6"
  protocol          = "tcp"
  port_range_min    = 443
  port_range_max    = 443
  remote_ip_prefix  = "::/0"
  security_group_id = openstack_networking_secgroup_v2.infra_ffl_sg.id
}

data "openstack_blockstorage_volume_v3" "gateway_source_volume" {
  provider = openstack.base_project
  name     = var.base_volume
}
resource "openstack_blockstorage_volume_v3" "gateway_root_volume" {
  name          = "${var.deployment_id}_gateway_root_volume"
  size          = 40
  source_vol_id = data.openstack_blockstorage_volume_v3.gateway_source_volume.id
}

resource "openstack_blockstorage_volume_v3" "gateway_docker_volume" {
  name = "${var.deployment_id}_gateway_docker_volume"
  size = 104
}
resource "openstack_compute_instance_v2" "gateway" {
  name      = "${var.deployment_id}_gateway"
  flavor_id = data.openstack_compute_flavor_v2.flavor.id
  key_pair  = "${var.deployment_id}_ssh_key"
  user_data = <<EOF
#cloud-config
hostname: ${var.deployment_id}
fqdn: ${var.deployment_id}.athtem.eei.ericsson.se
prefer_fqdn_over_hostname: false
# disable cloud-init network config - VM still gets an IP address from DHCP (OpenStack)
network:
  config: disabled
growpart:
  mode: auto
  devices:
    - /
# cinder volumes presented to the VM as /dev/disk/by-id/virtio-<first 20 characters of volume ID>
fs_setup:
  - filesystem: ext4
    device: /dev/disk/by-id/virtio-${substr(openstack_blockstorage_volume_v3.gateway_docker_volume.id, 0, 20)}
    partition: none
mounts:
 - [/dev/disk/by-id/virtio-${substr(openstack_blockstorage_volume_v3.gateway_docker_volume.id, 0, 20)},/var/lib/docker/, ext4, defaults, "0", "0"]
write_files:
  # write authorized_keys after commands in runcmd
  - path: /home/lciadm100/.ssh/authorized_keys
    content: ${base64encode(var.ssh_public_key)}
    encoding: base64
    owner: "lciadm100:lciadm100"
    defer: true
  # prevent cloud-init running again on subsequent boots
  - path: /etc/cloud/cloud-init.disabled
    defer: true
  - path: /etc/nginx/conf.d/enm.conf
    content: ${base64encode(templatefile(join("/", [path.module, "nginx-enm.tftpl"]), { "deployment_id" = var.deployment_id }))}
    encoding: base64
  - path: /etc/nginx/proxy_ssl_config
    content: ${base64encode(templatefile(join("/", [path.module, "proxy_ssl_config.tftpl"]), { "deployment_id" = var.deployment_id }))}
    encoding: base64
  - path: /etc/netplan/99-netplan.yaml
    encoding: base64
    permissions: "0600"
    content: ${base64encode(templatefile(join("/", [path.module, "netplan.tftpl"]),
  {
    "external_ipv4_gateway" : data.openstack_networking_subnet_v2.external_ipv4.gateway_ip,
    "external_ipv6_gateway" : data.openstack_networking_subnet_v2.external_ipv6.gateway_ip,
    "external_ipv4_address" : join("/", [var.gateway_external_ip, split("/", data.openstack_networking_subnet_v2.external_ipv4.cidr)[1]]),
    "external_ipv6_address" : join("/", [var.gateway_external_ipv6, split("/", data.openstack_networking_subnet_v2.external_ipv6.cidr)[1]])
  }
))}

runcmd:
 - rm -f /etc/netplan/50-cloud-init.yaml
 - netplan apply
 - sleep 5 # wait for IP addresses to be fully up or nginx won't start
 - systemctl daemon-reload
 - systemctl reset-failed nginx
 - systemctl restart nginx
EOF
block_device {
  uuid                  = openstack_blockstorage_volume_v3.gateway_root_volume.id
  source_type           = "volume"
  boot_index            = 0
  destination_type      = "volume"
  delete_on_termination = false
}
block_device {
  uuid                  = openstack_blockstorage_volume_v3.gateway_docker_volume.id
  source_type           = "volume"
  boot_index            = 1
  destination_type      = "volume"
  delete_on_termination = false
}

network {
  port = openstack_networking_port_v2.gateway_external_port.id
}
network {
  port = openstack_networking_port_v2.gateway_port.id

}
}

