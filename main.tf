resource "random_string" "affinity_group_name" {
  length  = 16
  upper   = false
  number  = false
  special = false
}

resource "exoscale_affinity" "affinity_group" {
  name = random_string.affinity_group_name.result
  type = "host anti-affinity"

  lifecycle {
    ignore_changes = ["description"]
  }
}

resource "exoscale_nic" "priv_interface" {
  count = var.private_network != null ? var.instance_count : 0

  compute_id = exoscale_compute.this[count.index].id
  network_id = var.private_network.id
}

data "template_cloudinit_config" "config" {
  count = var.instance_count

  gzip          = false
  base64_encode = false

  part {
    filename     = "system_info.cfg"
    merge_type   = "list(append)+dict(recurse_array)+str()"
    content_type = "text/cloud-config"

    content = <<EOF
#cloud-config
system_info:
  default_user:
    name: terraform
EOF
  }

  part {
    filename     = "additional.cfg"
    merge_type   = "list(append)+dict(recurse_array)+str()"
    content_type = "text/cloud-config"
    content      = "${var.additional_user_data}"
  }

  part {
    filename     = "additional.sh"
    content_type = "text/x-shellscript"
    content      = "${var.additional_user_script}"
  }
}

data "exoscale_compute_template" "this" {
  zone = var.region
  name = var.template
}

resource "exoscale_compute" "this" {
  count = var.instance_count

  key_pair        = var.key_pair
  display_name    = var.display_name != "" ? format("%s-%s", var.display_name, count.index) : format("ip-%s", join("-", split(".", cidrhost(var.private_network.cidr, var.private_network.offset + count.index))))
  disk_size       = var.root_disk_size
  security_groups = var.security_groups
  size            = var.size
  template_id     = data.exoscale_compute_template.this.id
  zone            = var.region
  affinity_groups = [
    exoscale_affinity.affinity_group.name
  ]
  user_data = data.template_cloudinit_config.config[count.index].rendered

  tags = var.tags

  lifecycle {
    ignore_changes = ["user_data", "security_groups", "key_pair", "affinity_groups", "affinity_group_ids",
      "template", "template_id", # The provider changed the way it manages templates and there's no real backward-compatibility.
    ]
  }
}


resource "null_resource" "provisioner" {
  count      = var.instance_count
  depends_on = ["exoscale_compute.this", "exoscale_nic.priv_interface"]

  connection {
    type                = lookup(var.connection, "type", null)
    user                = lookup(var.connection, "user", "terraform")
    password            = lookup(var.connection, "password", null)
    host                = lookup(var.connection, "host", exoscale_compute.this[count.index].ip_address)
    port                = lookup(var.connection, "port", 22)
    timeout             = lookup(var.connection, "timeout", "")
    script_path         = lookup(var.connection, "script_path", null)
    private_key         = lookup(var.connection, "private_key", null)
    agent               = lookup(var.connection, "agent", null)
    agent_identity      = lookup(var.connection, "agent_identity", null)
    host_key            = lookup(var.connection, "host_key", null)
    https               = lookup(var.connection, "https", false)
    insecure            = lookup(var.connection, "insecure", false)
    use_ntlm            = lookup(var.connection, "use_ntlm", false)
    cacert              = lookup(var.connection, "cacert", null)
    bastion_host        = lookup(var.connection, "bastion_host", null)
    bastion_host_key    = lookup(var.connection, "bastion_host_key", null)
    bastion_port        = lookup(var.connection, "bastion_port", 22)
    bastion_user        = lookup(var.connection, "bastion_user", null)
    bastion_password    = lookup(var.connection, "bastion_password", null)
    bastion_private_key = lookup(var.connection, "bastion_private_key", null)
  }

  provisioner "ansible" {
    plays {
      playbook {
        file_path  = "${path.module}/ansible-data/playbooks/instance.yml"
        roles_path = ["${path.module}/ansible-data/roles"]
      }

      groups = ["instance"]
      become = true
      diff   = true
      check  = var.ansible_check

      extra_vars = {
        eth1_address = var.private_network != null ? format("%s/%s", cidrhost(var.private_network.cidr, var.private_network.offset + count.index), cidrnetmask(var.private_network.cidr)) : null
      }
    }

    ansible_ssh_settings {
      connect_timeout_seconds              = 60
      insecure_no_strict_host_key_checking = true
    }
  }
}


#########
# Puppet

module "puppet-node" {
  source         = "git::ssh://git@github.com/camptocamp/terraform-puppet-node.git"
  instance_count = var.puppet == null ? 0 : var.instance_count

  instances = [
    for i in range(length(exoscale_compute.this)) :
    {
      hostname = format("%s.%s", exoscale_compute.this[i].name, var.domain)
      connection = {
        host        = lookup(var.connection, "host", exoscale_compute.this[i].ip_address)
        private_key = lookup(var.connection, "private_key", null)
      }
    }
  ]

  server_address    = var.puppet != null ? lookup(var.puppet, "server_address", null) : null
  server_port       = var.puppet != null ? lookup(var.puppet, "server_port", 443) : 443
  ca_server_address = var.puppet != null ? lookup(var.puppet, "ca_server_address", null) : null
  ca_server_port    = var.puppet != null ? lookup(var.puppet, "ca_server_port", 443) : 443
  environment       = var.puppet != null ? lookup(var.puppet, "environment", null) : null
  role              = var.puppet != null ? lookup(var.puppet, "role", null) : null
  autosign_psk      = var.puppet != null ? lookup(var.puppet, "autosign_psk", null) : null

  deps_on = null_resource.provisioner[*].id
}

##########
# Rancher

module "rancher-host" {
  source         = "git::ssh://git@github.com/camptocamp/terraform-rancher-host.git"
  instance_count = var.rancher == null ? 0 : var.instance_count

  instances = [
    for i in range(length(exoscale_compute.this)) :
    {
      hostname = format("%s.%s", exoscale_compute.this[i].name, var.domain)
      agent_ip = exoscale_compute.this[i].ip_address
      connection = {
        host        = lookup(var.connection, "host", exoscale_compute.this[i].ip_address)
        private_key = lookup(var.connection, "private_key", null)
      }

      host_labels = merge(
        var.rancher != null ? var.rancher.host_labels : {},
        {
          "io.rancher.host.os"              = "linux"
          "io.rancher.host.provider"        = "openstack"
          "io.rancher.host.region"          = var.region
          "io.rancher.host.external_dns_ip" = exoscale_compute.this[i].ip_address
        }
      )
    }
  ]

  environment_id = var.rancher != null ? var.rancher.environment_id : ""

  deps_on = var.puppet != null ? module.puppet-node.this_provisioner_id : []
}
