packer {
  required_plugins {
    openstack = {
      version = "~> 1.1.1"
      source  = "github.com/hashicorp/openstack"
    }
    ansible = {
      source  = "github.com/hashicorp/ansible"
      version = "~> 1"
    }
  }
}
variable "ffe_version" {
  type=string
}
source "openstack" "rocky_build" {
  flavor                    = "86ecccb2-31a6-4ca9-9df4-2c042e028373"
  image_name                = "vlitp_rocky_gateway_${var.ffe_version}"
  networks                  = ["5998ecb3-ae56-40f7-a893-25fd46631739"]
  source_image              = "3650b726-bdf6-418f-bf6f-3c03f313c2c5"
  security_groups           = ["infra_packer_sg"]
  ssh_username              = "rocky"
  user_data_file            = "packer-cloud.cfg"
  ssh_ip_version            = 4
  ssh_clear_authorized_keys = true
  metadata ={ "ffe_vm": "gateway","ffe_version":"${var.ffe_version}"}
}

build {
  sources = ["source.openstack.rocky_build"]
  provisioner "ansible" {
    playbook_file = "./gateway.yml"
    galaxy_file = "requirements.yml"
  }
}

