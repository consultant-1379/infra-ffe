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
locals {
  ssh_key = "${var.deployment_id}_ssh_key"
}
resource "openstack_compute_keypair_v2" "ssh_key" {
  name       = local.ssh_key
  public_key = var.ssh_public_key
}

#Create TAF, Netsim and Selenium VMs, and related resources
module "gateway" {
  source                 = "../gateway"
  deployment_id          = var.deployment_id
  gateway_external_ip    = var.gateway_external_ip
  gateway_external_ipv6  = var.gateway_external_ipv6
  base_volume            = var.gateway_base_volume
  ssh_key                = local.ssh_key
  ssh_public_key         = var.ssh_public_key
  external_network_name  = var.external_network_name
  northbound_network     = var.northbound_network
  northbound_ipv4_subnet = var.northbound_ipv4_subnet
  northbound_ipv6_subnet = var.northbound_ipv6_subnet
  providers = {
    openstack              = openstack
    openstack.base_project = openstack.base_project
  }
}


module "tafex" {
  source                 = "../tafex"
  deployment_id          = var.deployment_id
  base_volume            = var.tafex_base_volume
  ssh_key                = local.ssh_key
  northbound_network     = var.northbound_network
  northbound_ipv4_subnet = var.northbound_ipv4_subnet
  northbound_ipv6_subnet = var.northbound_ipv6_subnet
  providers = {
    openstack              = openstack
    openstack.base_project = openstack.base_project
  }
}
module "netsim" {
  source                 = "../netsim"
  deployment_id          = var.deployment_id
  base_volume            = var.netsim_base_volume
  ssh_key                = local.ssh_key
  northbound_network     = var.northbound_network
  northbound_ipv4_subnet = var.northbound_ipv4_subnet
  northbound_ipv6_subnet = var.northbound_ipv6_subnet
  providers = {
    openstack              = openstack
    openstack.base_project = openstack.base_project
  }
}
module "seleniumhub" {
  source                 = "../seleniumhub"
  deployment_id          = var.deployment_id
  base_volume            = var.seleniumhub_base_volume
  ssh_key                = local.ssh_key
  northbound_network     = var.northbound_network
  northbound_ipv4_subnet = var.northbound_ipv4_subnet
  northbound_ipv6_subnet = var.northbound_ipv6_subnet
  providers = {
    openstack              = openstack
    openstack.base_project = openstack.base_project
  }
}
