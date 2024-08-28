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

data "openstack_compute_flavor_v2" "flavor" {
  name = var.flavor
}

data "openstack_networking_subnet_v2" "external_ipv4" {
  network_id = var.external_network_id
  ip_version = 4
}

data "openstack_images_image_v2" "image" {
  name = var.image
}

// Security Group
resource "openstack_networking_secgroup_v2" "infra_vlitp_sg" {
  name = "${var.deployment_id}_security_group"
}
resource "openstack_networking_secgroup_rule_v2" "infra_vlitp_sg_rules" {
  direction        = "ingress"
  ethertype        = "IPv4"
  for_each         = var.open_ports
  protocol         = lookup(each.value, "protocol", "") != "" ? each.value.protocol : "tcp"
  port_range_min   = lookup(each.value, "min", null)
  port_range_max   = lookup(each.value, "max", null)
  remote_ip_prefix = "0.0.0.0/0"

  security_group_id = openstack_networking_secgroup_v2.infra_vlitp_sg.id
}

resource "openstack_networking_port_v2" "gateway_public_port" {
  name           = "${var.deployment_id}_gateway_public"
  network_id     = var.external_network_id
  admin_state_up = "true"
  fixed_ip {
    subnet_id  = var.external_subnet_ipv4_id
    ip_address = var.public_ip
  }
  security_group_ids = [openstack_networking_secgroup_v2.infra_vlitp_sg.id]
}
resource "openstack_networking_port_v2" "gateway_ports" {
  name           = "${var.deployment_id}_gateway_${each.key}"
  for_each       = var.gateway_ports
  network_id     = var.networks[each.key].network_id
  admin_state_up = "true"
  fixed_ip {
    subnet_id  = var.networks[each.key].subnet_id
    ip_address = cidrhost(var.networks[each.key].cidr, 1)
  }
  mac_address = each.value
  tags        = contains(["storage", "storint"], each.key) ? ["edp", each.key, "${var.deployment_id}_gateway_${each.key}"] : []
}

resource "openstack_blockstorage_volume_v3" "edp_volume" {
  name = "${var.deployment_id}_edp"
  size = var.edp_volume_size
}

resource "openstack_compute_instance_v2" "gateway" {
  name      = "${var.deployment_id}_gateway"
  flavor_id = data.openstack_compute_flavor_v2.flavor.id
  key_pair  = "${var.deployment_id}_key"
  image_id  = data.openstack_images_image_v2.image.id
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
  - filesystem: xfs
    device: /dev/disk/by-id/virtio-${substr(openstack_blockstorage_volume_v3.edp_volume.id, 0, 20)}
    partition: none
mounts:
 - [/dev/disk/by-id/virtio-${substr(openstack_blockstorage_volume_v3.edp_volume.id, 0, 20)},/var/edp, xfs, defaults, "0", "0"]
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
  - path: /var/tmp/getps.sh
    content: ${base64encode(file(join("/", [path.module, "getps.sh"])))}
    encoding: base64
    permissions: "0755"
  - path: /etc/ssh/sshd_config.d/99-custom.conf
    encoding: base64
    permissions: "0644"
    content: ${base64encode(templatefile(join("/", [path.module, "sshd_conf_custom.tftpl"]), { "public_ip" : var.public_ip }))}
  - path: /etc/netplan/99-netplan.yaml
    encoding: base64
    permissions: "0600"
    content: ${base64encode(templatefile(join("/", [path.module, "netplan.tftpl"]),
  {
    "external_ipv4_gateway" : data.openstack_networking_subnet_v2.external_ipv4.gateway_ip,
    "external_ipv4_address" : join("/", [var.public_ip, split("/", data.openstack_networking_subnet_v2.external_ipv4.cidr)[1]]),
  }
))}
  - path: /etc/networkd-dispatcher/routable.d/01-custom-routes
    content: ${base64encode(file(join("/", [path.module, "custom-routes"])))}
    encoding: base64
    permissions: "0755"

runcmd:
 - mkdir /home/lciadm100/.ssh
 - chown lciadm100:lciadm100 /home/lciadm100/.ssh && chmod 700 /home/lciadm100/.ssh
 - openssl req -new -x509 -config /etc/nginx/proxy_ssl_config -out /etc/nginx/proxycer.pem -keyout /etc/nginx/proxykey.pem -days 365 -noenc
 - openssl req -new -x509 -config /etc/nginx/proxy_ssl_config -keyout /hwsim/etc/localhost.pem -out /hwsim/etc/localhost.pem -days 365 -noenc
 - mkdir -p /var/edp/vol1/
 - rm -f /etc/netplan/50-cloud-init.yaml
 - netplan apply
 - systemctl daemon-reload
 - systemctl reset-failed nginx
 - systemctl restart nginx
 - systemctl restart sshd
 - iptables-restore /etc/iptables/rules.v4
 - ip6tables-restore /etc/iptables/rules.v6
EOF
block_device {
  uuid                  = data.openstack_images_image_v2.image.id
  source_type           = "image"
  destination_type      = "local"
  boot_index            = 0
  delete_on_termination = true
}
block_device {
  uuid                  = openstack_blockstorage_volume_v3.edp_volume.id
  source_type           = "volume"
  boot_index            = 1
  destination_type      = "volume"
  delete_on_termination = false
}
network {
  port = openstack_networking_port_v2.gateway_public_port.id
}

dynamic "network" {
  for_each = openstack_networking_port_v2.gateway_ports
  content {
    port = network.value.id
  }
}
}
