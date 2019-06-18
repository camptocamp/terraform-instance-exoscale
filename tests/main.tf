###
# Variables
#
variable "key_pair" {}

###
# Datasources
#
data "pass_password" "puppet_autosign_psk" {
  path = "terraform/c2c_mgmtsrv/puppet_autosign_psk"
}

###
# Code to test
#
variable "instance_count" {
  default = 1
}

module "instance" {
  source         = "../"
  instance_count = var.instance_count

  key_pair      = var.key_pair
  instance_name = "terraform-instance-exoscale-test"
  domain        = "internal"

  security_groups = [
    "allow_c2c"
  ]

  instance_type  = "Small"
  instance_image = "Linux Ubuntu 16.04 LTS 64-bit"
  region         = "ch-gva-2"
  root_disk_size = "50"
}
