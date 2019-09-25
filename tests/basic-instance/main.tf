###
# Datasources
#
data "pass_password" "puppet_autosign_psk" {
  path = "terraform/c2c_mgmtsrv/puppet_autosign_psk"
}

data "pass_password" "ssh_key" {
  path = "terraform/ssh/terraform"
}

###
# Code to test
#
resource "exoscale_security_group" "test_basic_instance" {
  name = "test-basic-instance"
}

resource "exoscale_security_group_rules" "test_basic_instance" {
  security_group_id = exoscale_security_group.test_basic_instance.id

  ingress {
    protocol  = "TCP"
    ports     = ["22"]
    cidr_list = ["0.0.0.0/0", "::/0"]
  }
}

module "instance" {
  source         = "../../"
  instance_count = 1

  key_pair     = "terraform"
  display_name = "terraform-testing-basic-instance"
  domain       = "internal"

  security_groups = [
    "test-basic-instance"
  ]

  size           = "Small"
  template       = "Linux Ubuntu 16.04 LTS 64-bit"
  region         = "ch-gva-2"
  root_disk_size = "50"

  puppet = {
    autosign_psk      = data.pass_password.puppet_autosign_psk.data["puppet_autosign_psk"]
    server_address    = "puppet.camptocamp.com"
    ca_server_address = "puppetca.camptocamp.com"
    role              = "base"
    environment       = "staging4"
  }

  connection = {
    private_key = data.pass_password.ssh_key.data["id_rsa"]
  }
}

###
# Acceptance test
#
resource "null_resource" "acceptance" {
  count      = 1
  depends_on = ["module.instance"]

  connection {
    host        = coalesce(module.instance.this_instance_public_ipv4[count.index], (length(module.instance.this_instance_public_ipv6[count.index]) > 0 ? module.instance.this_instance_public_ipv6[count.index][0] : ""))
    type        = "ssh"
    user        = "terraform"
    private_key = data.pass_password.ssh_key.data["id_rsa"]
  }

  provisioner "file" {
    source      = "script.sh"
    destination = "/tmp/script.sh"
  }

  provisioner "file" {
    source      = "goss.yaml"
    destination = "/home/terraform/goss.yaml"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/script.sh",
      "sudo /tmp/script.sh",
    ]
  }
}
