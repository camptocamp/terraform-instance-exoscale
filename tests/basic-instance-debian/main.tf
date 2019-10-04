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
resource "exoscale_security_group" "test_basic_instance_debian" {
  name = "test-basic-instance-debian"
}

resource "exoscale_security_group_rules" "test_basic_instance_debian" {
  security_group_id = exoscale_security_group.test_basic_instance_debian.id

  ingress {
    protocol  = "TCP"
    ports     = ["22"]
    cidr_list = ["0.0.0.0/0", "::/0"]
  }
}

resource "exoscale_network" "priv_net" {
  name             = "privNetTestingTerraform"
  zone             = "ch-gva-2"
  network_offering = "PrivNet"
}

module "instance" {
  source         = "../../"
  instance_count = 1

  key_pair = "terraform"
  domain   = "internal"

  private_network = {
    id     = exoscale_network.priv_net.id
    cidr   = "10.10.99.0/24"
    offset = 20
  }
  security_groups = [
    "test-basic-instance-debian"
  ]

  size           = "Small"
  template       = "Linux Debian 10 (Buster) 64-bit"
  region         = "ch-gva-2"
  root_disk_size = "50"

  tags = {
    Name = "testing terraform instance debian"
  }

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

  provisioner "remote-exec" {
    inline = [
      "sudo apt-get install curl -y",
    ]
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
