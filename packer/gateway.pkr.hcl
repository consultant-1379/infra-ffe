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
source "openstack" "ubuntu_build" {
  flavor                    = "818ed9a8-2236-42cd-b5b2-c49527aa0119"
  image_name                = "gateway_${var.ffe_version}"
  networks                  = ["5998ecb3-ae56-40f7-a893-25fd46631739"]
  source_image              = "15c76844-f5e2-4624-9ec8-8bcbcaaed98a"
  security_groups           = ["infra_packer_sg"]
  ssh_username              = "ubuntu"
  user_data_file            = "packer-cloud.cfg"
  ssh_ip_version            = 4
  ssh_clear_authorized_keys = true
  metadata ={ "ffe_vm": "gateway","ffe_version":"${var.ffe_version}"}
}

build {
  sources = ["source.openstack.ubuntu_build"]
  provisioner "ansible" {
    playbook_file = "./gateway.yml"
    galaxy_file = "requirements.yml"
  }
}

