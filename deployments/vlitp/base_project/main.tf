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
  tenant_name = "vLITP_infra_admin"
}
# LMS
resource "openstack_images_image_v2" "rhel_ks_iso" {
  name             = "rhel-ks2.iso"
  image_source_url = var.lms_image_url
  disk_format      = "iso"
  container_format = "bare"
  properties = {
    hw_scsi_model    = "virtio-scsi",
    hw_disk_bus      = "scsi",
    hw_firmware_type = "uefi",
    hw_machine_type  = "q35",
    architecture     = "x86_64"
  }
  protected  = true
  visibility = "public"
}

resource "openstack_images_image_v2" "va_image" {
  name             = "vlitp-va-ready"
  image_source_url = var.va_image_url
  container_format = "bare"
  disk_format      = "qcow2"
  protected        = true
  visibility       = "public"
}

# Flavors
resource "openstack_compute_flavor_v2" "gateway_flavor" {
  name      = "vlitp_gateway_flavor"
  vcpus     = 2
  ram       = 8192
  disk      = 20
  is_public = true
}

resource "openstack_compute_flavor_v2" "lms_flavor" {
  name      = "vlitp_lms_flavor"
  vcpus     = 4
  ram       = 49152
  disk      = 0
  is_public = true
}

resource "openstack_compute_flavor_v2" "nas_flavor" {
  name      = "vlitp_nas_flavor"
  vcpus     = 2
  ram       = 32768
  disk      = 100
  is_public = true
}

resource "openstack_compute_flavor_v2" "db_node_flavor" {
  name      = "vlitp_db_node_flavor"
  vcpus     = 4
  ram       = 98304
  disk      = 0
  is_public = true
}

resource "openstack_compute_flavor_v2" "svc_node_flavor" {
  name      = "vlitp_svc_node_flavor"
  vcpus     = 8
  ram       = 98304
  disk      = 0
  is_public = true
}
