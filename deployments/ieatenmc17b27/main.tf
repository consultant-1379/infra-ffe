terraform {
  required_version = ">= 0.14.0"
  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "~> 1.54.1"
    }
  }

}
provider "openstack" {
  tenant_name = "ENM_FFE_C17B27"
}

provider "openstack" {
  alias       = "base_project"
  tenant_name = "FFE_infra_admin"
}
resource "openstack_networking_network_v2" "northbound" {
  name           = "ieatenmc17b27_northbound"
  admin_state_up = "true"
}

resource "openstack_networking_subnet_v2" "northbound_subnet_ipv4" {
  name       = "ieatenmc17b27_northbound_ipv4"
  network_id = openstack_networking_network_v2.northbound.id
  cidr       = "192.168.0.0/16"
  ip_version = 4
  no_gateway = "true"
  allocation_pool {
    start = "192.168.0.3"
    end   = "192.168.0.79"
  }
}

resource "openstack_networking_subnet_v2" "northbound_subnet_ipv6" {
  name       = "ieatenmc17b27_northbound_ipv6"
  network_id = openstack_networking_network_v2.northbound.id
  cidr       = "2001:1b70:82a1:103::/64"
  ip_version = 6
  no_gateway = "true"
  allocation_pool {
    start = "2001:1b70:82a1:103::10"
    end   = "2001:1b70:82a1:103::50"
  }
}
# moved blocks - to allow module re-organisation without recreating all resources.
moved {
  from = module.ieatenmc17b27.openstack_networking_port_v2.gateway_external_port
  to   = module.ieatenmc17b27.module.gateway.openstack_networking_port_v2.gateway_external_port
}
moved {
  from = module.ieatenmc17b27.openstack_networking_port_v2.gateway_port
  to   = module.ieatenmc17b27.module.gateway.openstack_networking_port_v2.gateway_port
}
moved {
  from = module.ieatenmc17b27.openstack_networking_secgroup_rule_v2.http_ui
  to   = module.ieatenmc17b27.module.gateway.openstack_networking_secgroup_rule_v2.http_ui
}
moved {
  from = module.ieatenmc17b27.openstack_networking_secgroup_rule_v2.http_ui_v6
  to   = module.ieatenmc17b27.module.gateway.openstack_networking_secgroup_rule_v2.http_ui_v6
}
moved {
  from = module.ieatenmc17b27.openstack_networking_secgroup_rule_v2.https_ui
  to   = module.ieatenmc17b27.module.gateway.openstack_networking_secgroup_rule_v2.https_ui
}
moved {
  from = module.ieatenmc17b27.openstack_networking_secgroup_rule_v2.https_ui_v6
  to   = module.ieatenmc17b27.module.gateway.openstack_networking_secgroup_rule_v2.https_ui_v6
}
moved {
  from = module.ieatenmc17b27.openstack_networking_secgroup_rule_v2.icmp
  to   = module.ieatenmc17b27.module.gateway.openstack_networking_secgroup_rule_v2.icmp
}
moved {
  from = module.ieatenmc17b27.openstack_networking_secgroup_rule_v2.icmp_v6
  to   = module.ieatenmc17b27.module.gateway.openstack_networking_secgroup_rule_v2.icmp_v6
}
moved {
  from = module.ieatenmc17b27.openstack_networking_secgroup_rule_v2.netsim_ssh
  to   = module.ieatenmc17b27.module.gateway.openstack_networking_secgroup_rule_v2.netsim_ssh
}
moved {
  from = module.ieatenmc17b27.openstack_networking_secgroup_rule_v2.netsim_ssh_v6
  to   = module.ieatenmc17b27.module.gateway.openstack_networking_secgroup_rule_v2.netsim_ssh_v6
}
moved {
  from = module.ieatenmc17b27.openstack_networking_secgroup_rule_v2.netsim_telnet
  to   = module.ieatenmc17b27.module.gateway.openstack_networking_secgroup_rule_v2.netsim_telnet
}
moved {
  from = module.ieatenmc17b27.openstack_networking_secgroup_rule_v2.netsim_telnet_v6
  to   = module.ieatenmc17b27.module.gateway.openstack_networking_secgroup_rule_v2.netsim_telnet_v6
}
moved {
  from = module.ieatenmc17b27.openstack_networking_secgroup_rule_v2.ssh
  to   = module.ieatenmc17b27.module.gateway.openstack_networking_secgroup_rule_v2.ssh
}
moved {
  from = module.ieatenmc17b27.openstack_networking_secgroup_rule_v2.ssh_v6
  to   = module.ieatenmc17b27.module.gateway.openstack_networking_secgroup_rule_v2.ssh_v6
}
moved {
  from = module.ieatenmc17b27.openstack_networking_secgroup_rule_v2.tafexem1_jenkins
  to   = module.ieatenmc17b27.module.gateway.openstack_networking_secgroup_rule_v2.tafexem1_jenkins
}
moved {
  from = module.ieatenmc17b27.openstack_networking_secgroup_rule_v2.tafexem1_jenkins_v6
  to   = module.ieatenmc17b27.module.gateway.openstack_networking_secgroup_rule_v2.tafexem1_jenkins_v6
}
moved {
  from = module.ieatenmc17b27.openstack_networking_secgroup_rule_v2.vnflaf_ui
  to   = module.ieatenmc17b27.module.gateway.openstack_networking_secgroup_rule_v2.vnflaf_ui
}
moved {
  from = module.ieatenmc17b27.openstack_networking_secgroup_rule_v2.vnflaf_ui_v6
  to   = module.ieatenmc17b27.module.gateway.openstack_networking_secgroup_rule_v2.vnflaf_ui_v6
}
moved {
  from = module.ieatenmc17b27.openstack_networking_secgroup_v2.infra_ffl_sg
  to   = module.ieatenmc17b27.module.gateway.openstack_networking_secgroup_v2.infra_ffl_sg
}
moved {
  from = module.ieatenmc17b27.openstack_blockstorage_volume_v3.gateway_docker_volume
  to   = module.ieatenmc17b27.module.gateway.openstack_blockstorage_volume_v3.gateway_docker_volume
}
moved {
  from = module.ieatenmc17b27.openstack_blockstorage_volume_v3.gateway_root_volume
  to   = module.ieatenmc17b27.module.gateway.openstack_blockstorage_volume_v3.gateway_root_volume
}
moved {
  from = module.ieatenmc17b27.openstack_compute_instance_v2.gateway
  to   = module.ieatenmc17b27.module.gateway.openstack_compute_instance_v2.gateway
}
# moved blocks - to allow module re-organisation without recreating all resources.
moved {
  from = module.ieatenmc17b27.openstack_networking_port_v2.gateway_external_port
  to   = module.ieatenmc17b27.module.gateway.openstack_networking_port_v2.gateway_external_port
}
moved {
  from = module.ieatenmc17b27.openstack_networking_port_v2.gateway_port
  to   = module.ieatenmc17b27.module.gateway.openstack_networking_port_v2.gateway_port
}
moved {
  from = module.ieatenmc17b27.openstack_networking_secgroup_rule_v2.http_ui
  to   = module.ieatenmc17b27.module.gateway.openstack_networking_secgroup_rule_v2.http_ui
}
moved {
  from = module.ieatenmc17b27.openstack_networking_secgroup_rule_v2.http_ui_v6
  to   = module.ieatenmc17b27.module.gateway.openstack_networking_secgroup_rule_v2.http_ui_v6
}
moved {
  from = module.ieatenmc17b27.openstack_networking_secgroup_rule_v2.https_ui
  to   = module.ieatenmc17b27.module.gateway.openstack_networking_secgroup_rule_v2.https_ui
}
moved {
  from = module.ieatenmc17b27.openstack_networking_secgroup_rule_v2.https_ui_v6
  to   = module.ieatenmc17b27.module.gateway.openstack_networking_secgroup_rule_v2.https_ui_v6
}
moved {
  from = module.ieatenmc17b27.openstack_networking_secgroup_rule_v2.icmp
  to   = module.ieatenmc17b27.module.gateway.openstack_networking_secgroup_rule_v2.icmp
}
moved {
  from = module.ieatenmc17b27.openstack_networking_secgroup_rule_v2.icmp_v6
  to   = module.ieatenmc17b27.module.gateway.openstack_networking_secgroup_rule_v2.icmp_v6
}
moved {
  from = module.ieatenmc17b27.openstack_networking_secgroup_rule_v2.netsim_ssh
  to   = module.ieatenmc17b27.module.gateway.openstack_networking_secgroup_rule_v2.netsim_ssh
}
moved {
  from = module.ieatenmc17b27.openstack_networking_secgroup_rule_v2.netsim_ssh_v6
  to   = module.ieatenmc17b27.module.gateway.openstack_networking_secgroup_rule_v2.netsim_ssh_v6
}
moved {
  from = module.ieatenmc17b27.openstack_networking_secgroup_rule_v2.netsim_telnet
  to   = module.ieatenmc17b27.module.gateway.openstack_networking_secgroup_rule_v2.netsim_telnet
}
moved {
  from = module.ieatenmc17b27.openstack_networking_secgroup_rule_v2.netsim_telnet_v6
  to   = module.ieatenmc17b27.module.gateway.openstack_networking_secgroup_rule_v2.netsim_telnet_v6
}
moved {
  from = module.ieatenmc17b27.openstack_networking_secgroup_rule_v2.ssh
  to   = module.ieatenmc17b27.module.gateway.openstack_networking_secgroup_rule_v2.ssh
}
moved {
  from = module.ieatenmc17b27.openstack_networking_secgroup_rule_v2.ssh_v6
  to   = module.ieatenmc17b27.module.gateway.openstack_networking_secgroup_rule_v2.ssh_v6
}
moved {
  from = module.ieatenmc17b27.openstack_networking_secgroup_rule_v2.tafexem1_jenkins
  to   = module.ieatenmc17b27.module.gateway.openstack_networking_secgroup_rule_v2.tafexem1_jenkins
}
moved {
  from = module.ieatenmc17b27.openstack_networking_secgroup_rule_v2.tafexem1_jenkins_v6
  to   = module.ieatenmc17b27.module.gateway.openstack_networking_secgroup_rule_v2.tafexem1_jenkins_v6
}
moved {
  from = module.ieatenmc17b27.openstack_networking_secgroup_rule_v2.vnflaf_ui
  to   = module.ieatenmc17b27.module.gateway.openstack_networking_secgroup_rule_v2.vnflaf_ui
}
moved {
  from = module.ieatenmc17b27.openstack_networking_secgroup_rule_v2.vnflaf_ui_v6
  to   = module.ieatenmc17b27.module.gateway.openstack_networking_secgroup_rule_v2.vnflaf_ui_v6
}
moved {
  from = module.ieatenmc17b27.openstack_networking_secgroup_v2.infra_ffl_sg
  to   = module.ieatenmc17b27.module.gateway.openstack_networking_secgroup_v2.infra_ffl_sg
}
moved {
  from = module.ieatenmc17b27.openstack_blockstorage_volume_v3.gateway_docker_volume
  to   = module.ieatenmc17b27.module.gateway.openstack_blockstorage_volume_v3.gateway_docker_volume
}
moved {
  from = module.ieatenmc17b27.openstack_blockstorage_volume_v3.gateway_root_volume
  to   = module.ieatenmc17b27.module.gateway.openstack_blockstorage_volume_v3.gateway_root_volume
}
moved {
  from = module.ieatenmc17b27.openstack_compute_instance_v2.gateway
  to   = module.ieatenmc17b27.module.gateway.openstack_compute_instance_v2.gateway
} # moved blocks - to allow module re-organisation without recreating all resources.
moved {
  from = module.ieatenmc17b27.openstack_networking_port_v2.gateway_external_port
  to   = module.ieatenmc17b27.module.gateway.openstack_networking_port_v2.gateway_external_port
}
moved {
  from = module.ieatenmc17b27.openstack_networking_port_v2.gateway_port
  to   = module.ieatenmc17b27.module.gateway.openstack_networking_port_v2.gateway_port
}
moved {
  from = module.ieatenmc17b27.openstack_networking_secgroup_rule_v2.http_ui
  to   = module.ieatenmc17b27.module.gateway.openstack_networking_secgroup_rule_v2.http_ui
}
moved {
  from = module.ieatenmc17b27.openstack_networking_secgroup_rule_v2.http_ui_v6
  to   = module.ieatenmc17b27.module.gateway.openstack_networking_secgroup_rule_v2.http_ui_v6
}
moved {
  from = module.ieatenmc17b27.openstack_networking_secgroup_rule_v2.https_ui
  to   = module.ieatenmc17b27.module.gateway.openstack_networking_secgroup_rule_v2.https_ui
}
moved {
  from = module.ieatenmc17b27.openstack_networking_secgroup_rule_v2.https_ui_v6
  to   = module.ieatenmc17b27.module.gateway.openstack_networking_secgroup_rule_v2.https_ui_v6
}
moved {
  from = module.ieatenmc17b27.openstack_networking_secgroup_rule_v2.icmp
  to   = module.ieatenmc17b27.module.gateway.openstack_networking_secgroup_rule_v2.icmp
}
moved {
  from = module.ieatenmc17b27.openstack_networking_secgroup_rule_v2.icmp_v6
  to   = module.ieatenmc17b27.module.gateway.openstack_networking_secgroup_rule_v2.icmp_v6
}
moved {
  from = module.ieatenmc17b27.openstack_networking_secgroup_rule_v2.netsim_ssh
  to   = module.ieatenmc17b27.module.gateway.openstack_networking_secgroup_rule_v2.netsim_ssh
}
moved {
  from = module.ieatenmc17b27.openstack_networking_secgroup_rule_v2.netsim_ssh_v6
  to   = module.ieatenmc17b27.module.gateway.openstack_networking_secgroup_rule_v2.netsim_ssh_v6
}
moved {
  from = module.ieatenmc17b27.openstack_networking_secgroup_rule_v2.netsim_telnet
  to   = module.ieatenmc17b27.module.gateway.openstack_networking_secgroup_rule_v2.netsim_telnet
}
moved {
  from = module.ieatenmc17b27.openstack_networking_secgroup_rule_v2.netsim_telnet_v6
  to   = module.ieatenmc17b27.module.gateway.openstack_networking_secgroup_rule_v2.netsim_telnet_v6
}
moved {
  from = module.ieatenmc17b27.openstack_networking_secgroup_rule_v2.ssh
  to   = module.ieatenmc17b27.module.gateway.openstack_networking_secgroup_rule_v2.ssh
}
moved {
  from = module.ieatenmc17b27.openstack_networking_secgroup_rule_v2.ssh_v6
  to   = module.ieatenmc17b27.module.gateway.openstack_networking_secgroup_rule_v2.ssh_v6
}
moved {
  from = module.ieatenmc17b27.openstack_networking_secgroup_rule_v2.tafexem1_jenkins
  to   = module.ieatenmc17b27.module.gateway.openstack_networking_secgroup_rule_v2.tafexem1_jenkins
}
moved {
  from = module.ieatenmc17b27.openstack_networking_secgroup_rule_v2.tafexem1_jenkins_v6
  to   = module.ieatenmc17b27.module.gateway.openstack_networking_secgroup_rule_v2.tafexem1_jenkins_v6
}
moved {
  from = module.ieatenmc17b27.openstack_networking_secgroup_rule_v2.vnflaf_ui
  to   = module.ieatenmc17b27.module.gateway.openstack_networking_secgroup_rule_v2.vnflaf_ui
}
moved {
  from = module.ieatenmc17b27.openstack_networking_secgroup_rule_v2.vnflaf_ui_v6
  to   = module.ieatenmc17b27.module.gateway.openstack_networking_secgroup_rule_v2.vnflaf_ui_v6
}
moved {
  from = module.ieatenmc17b27.openstack_networking_secgroup_v2.infra_ffl_sg
  to   = module.ieatenmc17b27.module.gateway.openstack_networking_secgroup_v2.infra_ffl_sg
}
moved {
  from = module.ieatenmc17b27.openstack_blockstorage_volume_v3.gateway_docker_volume
  to   = module.ieatenmc17b27.module.gateway.openstack_blockstorage_volume_v3.gateway_docker_volume
}
moved {
  from = module.ieatenmc17b27.openstack_blockstorage_volume_v3.gateway_root_volume
  to   = module.ieatenmc17b27.module.gateway.openstack_blockstorage_volume_v3.gateway_root_volume
}
moved {
  from = module.ieatenmc17b27.openstack_compute_instance_v2.gateway
  to   = module.ieatenmc17b27.module.gateway.openstack_compute_instance_v2.gateway
}

module "ieatenmc17b27" {
  source                 = "../../modules/ffe"
  deployment_id          = "ieatenmc17b27"
  gateway_external_ip    = "10.150.226.234"
  gateway_external_ipv6  = "2001:1b70:82b9:256::1027:1"
  ssh_public_key         = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEcxg8oyGG7OgXWbb3nUxvagGDetLaLwEofJWtrPQpql"
  external_network_name  = "p122-opstk-17b-public-tenant2"
  northbound_network     = openstack_networking_network_v2.northbound.id
  northbound_ipv4_subnet = openstack_networking_subnet_v2.northbound_subnet_ipv4.id
  northbound_ipv6_subnet = openstack_networking_subnet_v2.northbound_subnet_ipv6.id
  providers = {
    openstack              = openstack
    openstack.base_project = openstack.base_project
  }
  gateway_base_volume     = "gateway_base_root_volume"
  netsim_base_volume      = "netsim_base_root_volume"
  tafex_base_volume       = "tafex_base_root_volume"
  seleniumhub_base_volume = "seleniumhub_base_root_volume"

}
