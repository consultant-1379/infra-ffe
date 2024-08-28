terraform {
  required_version = ">= 0.14.0"
  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "~> 1.52.1"
    }
  }

}
provider "openstack" {
  tenant_name = "EE_TAF_C17B23"
}

provider "openstack" {
  alias       = "base_project"
  tenant_name = "FFE_infra_admin"
}
resource "openstack_networking_network_v2" "northbound" {
  name           = "ieatenmc17b23_northbound"
  admin_state_up = "true"
}

resource "openstack_networking_subnet_v2" "northbound_subnet_ipv4" {
  name       = "ieatenmc17b23_northbound_ipv4"
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
  name       = "ieatenmc17b23_northbound_ipv6"
  network_id = openstack_networking_network_v2.northbound.id
  cidr       = "2001:1b70:82a1:103::/64"
  ip_version = 6
  no_gateway = "true"
  allocation_pool {
    start = "2001:1b70:82a1:103::10"
    end   = "2001:1b70:82a1:103::50"
  }
}


module "ieatenmc17b23" {
  source                 = "../../modules/venm"
  deployment_id          = "ieatenmc17b23"
  gateway_external_ip    = "10.150.226.238"
  gateway_external_ipv6  = "2001:1b70:82b9:256::1023:1"
  ssh_public_key         = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILiwAOyJqxbWe5U+edOkFQu5Iu8+k8OtTwpmmZbfpTXf"
  external_network_name  = "p122-opstk-17b-public-tenant2"
  northbound_network     = openstack_networking_network_v2.northbound.id
  northbound_ipv4_subnet = openstack_networking_subnet_v2.northbound_subnet_ipv4.id
  northbound_ipv6_subnet = openstack_networking_subnet_v2.northbound_subnet_ipv6.id
  providers = {
    openstack              = openstack
    openstack.base_project = openstack.base_project
  }
}
