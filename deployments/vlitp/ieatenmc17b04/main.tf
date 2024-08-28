terraform {
  required_version = ">= 0.14.0"
  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "~> 1.54.1"
    }
  }

}

//Networks
data "openstack_networking_network_v2" "external_network" {
  name = var.external_network
}
data "openstack_networking_subnet_v2" "external_subnet_ipv4" {
  network_id = data.openstack_networking_network_v2.external_network.id
  ip_version = 4
}
provider "openstack" {
  tenant_name = var.project
}
provider "openstack" {
  alias       = "base_project"
  tenant_name = var.base_project
}

# Paths below are relative to the deployments/vlitp/<deployment id> directory
module "common_infra" {
  source              = "../../../modules/vlitp/common"
  deployment_id       = var.deployment_id
  ssh_public_key      = var.ssh_public_key
  external_network_id = data.openstack_networking_network_v2.external_network.id
  providers = {
    openstack              = openstack
    openstack.base_project = openstack.base_project
  }
}

module "gateway" {
  source                  = "../../../modules/vlitp/gateway"
  external_network_id     = data.openstack_networking_network_v2.external_network.id
  external_subnet_ipv4_id = data.openstack_networking_subnet_v2.external_subnet_ipv4.id
  deployment_id           = var.deployment_id
  public_ip               = var.public_ip
  ssh_public_key          = var.ssh_public_key
  networks                = module.common_infra.networks
  flavor                  = "vlitp_gateway_flavor"
  providers = {
    openstack              = openstack
    openstack.base_project = openstack.base_project
  }
}
module "lms" {
  source        = "../../../modules/vlitp/lms"
  deployment_id = var.deployment_id
  networks      = module.common_infra.networks
  vlans         = module.common_infra.vlans
  flavor        = "vlitp_lms_flavor"
  providers = {
    openstack              = openstack
    openstack.base_project = openstack.base_project
  }
}
module "nas" {
  source        = "../../../modules/vlitp/nas"
  deployment_id = var.deployment_id
  networks      = module.common_infra.networks
  flavor        = "vlitp_nas_flavor"
  providers = {
    openstack              = openstack
    openstack.base_project = openstack.base_project
  }
}
module "db_node" {
  count         = var.db_node_count
  source        = "../../../modules/vlitp/peer"
  deployment_id = var.deployment_id
  networks      = module.common_infra.networks
  vlans         = module.common_infra.vlans
  peer_num      = count.index
  node_type     = "db_node"
  flavor        = "vlitp_db_node_flavor"
  providers = {
    openstack              = openstack
    openstack.base_project = openstack.base_project
  }
}
module "svc_node" {
  count         = var.svc_node_count
  source        = "../../../modules/vlitp/peer"
  deployment_id = var.deployment_id
  networks      = module.common_infra.networks
  vlans         = module.common_infra.vlans
  peer_num      = count.index + var.db_node_count
  node_type     = "svc_node"
  flavor        = "vlitp_svc_node_flavor"
  providers = {
    openstack              = openstack
    openstack.base_project = openstack.base_project
  }
}

module "netsim" {
  source                 = "../../../modules/netsim"
  deployment_id          = var.deployment_id
  base_volume            = var.netsim_base_volume
  ssh_key                = "${var.deployment_id}_key"
  northbound_network     = module.common_infra.networks["service"].network_id
  northbound_ipv4_subnet = module.common_infra.networks["service"].subnet_id
  northbound_ipv6_subnet = module.common_infra.service_ipv6_subnet
  providers = {
    openstack              = openstack
    openstack.base_project = openstack.base_project
  }
}

module "seleniumhub" {
  source                 = "../../../modules/seleniumhub"
  deployment_id          = var.deployment_id
  base_volume            = var.seleniumhub_base_volume
  ssh_key                = "${var.deployment_id}_key"
  northbound_network     = module.common_infra.networks["service"].network_id
  northbound_ipv4_subnet = module.common_infra.networks["service"].subnet_id
  northbound_ipv6_subnet = module.common_infra.service_ipv6_subnet
  providers = {
    openstack              = openstack
    openstack.base_project = openstack.base_project
  }
}

module "tafex" {
  source                 = "../../../modules/tafex"
  deployment_id          = var.deployment_id
  base_volume            = var.tafex_base_volume
  ssh_key                = "${var.deployment_id}_key"
  northbound_network     = module.common_infra.networks["service"].network_id
  northbound_ipv4_subnet = module.common_infra.networks["service"].subnet_id
  northbound_ipv6_subnet = module.common_infra.service_ipv6_subnet
  providers = {
    openstack              = openstack
    openstack.base_project = openstack.base_project
  }
}
