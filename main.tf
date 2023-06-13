resource "exoscale_anti_affinity_group" "affinity_group" {
  name = "${var.hostname}-nodes"

  lifecycle {
    ignore_changes = [description]
  }
}

resource "exoscale_nic" "priv_interface" {
  count = var.private_network != null ? var.instance_count : 0

  compute_id = exoscale_compute_instance.this[count.index].id
  network_id = var.private_network.id
}

module "freeipa_host" {
  count = var.freeipa != null ? (var.freeipa.domain != null ? var.instance_count : 0) : 0

  source = "git::https://github.com/camptocamp/terraform-freeipa-host.git?ref=v1.x"

  hostname = format("%s-%d.%s", var.hostname, count.index, var.domain)
  domain   = var.freeipa.domain

  force = true
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
    filename     = "freeipa.cfg"
    merge_type   = "list(append)+dict(recurse_array)+str()"
    content_type = "text/cloud-config"
    content      = var.freeipa != null ? (var.freeipa.domain != null ? module.freeipa_host[count.index].cloudinit_config : "") : ""
  }

  part {
    filename     = "additional.cfg"
    merge_type   = "list(append)+dict(recurse_array)+str()"
    content_type = "text/cloud-config"
    content      = var.additional_user_data
  }

  part {
    filename     = "additional.sh"
    content_type = "text/x-shellscript"
    content      = var.additional_user_script
  }
}

resource "exoscale_security_group" "this" {
  name = "${var.hostname}-nodes"
}

resource "exoscale_security_group_rule" "this" {
  for_each = var.security_group_rules

  security_group_id = exoscale_security_group.this.id

  type        = each.value.type
  description = each.value.description
  protocol    = each.value.protocol
  cidr        = each.value.cidr
  start_port  = each.value.start_port
  end_port    = each.value.end_port
}

data "exoscale_compute_template" "this" {
  zone = var.region
  name = var.template
}

resource "exoscale_compute_instance" "this" {
  count = var.instance_count

  ssh_key     = var.ssh_key
  name        = var.hostname != "" ? format("%s-%s", var.hostname, count.index) : null
  reverse_dns = var.hostname != "" && var.domain != "" ? format("%s-%d.%s", var.hostname, count.index, var.domain) : null
  disk_size   = var.root_disk_size
  type        = var.type
  template_id = data.exoscale_compute_template.this.id
  zone        = var.region
  user_data   = data.template_cloudinit_config.config[count.index].rendered
  labels      = var.tags

  anti_affinity_group_ids = [
    exoscale_anti_affinity_group.affinity_group.id
  ]

  security_group_ids = var.security_group_ids
}

resource "freeipa_dns_record" "this" {
  count = var.freeipa != null ? (var.freeipa.dns_zone != null ? var.instance_count : 0) : 0

  dnszoneidnsname = var.freeipa.dns_zone
  idnsname        = exoscale_compute_instance.this[count.index].name
  records         = ["${exoscale_compute_instance.this[count.index].public_ip_address}"]
  dnsttl          = 300
  type            = "A"
}

resource "null_resource" "provisioner" {
  count      = var.instance_count
  depends_on = [exoscale_compute_instance.this, exoscale_nic.priv_interface]

  connection {
    type                = lookup(var.connection, "type", null)
    user                = lookup(var.connection, "user", "terraform")
    password            = lookup(var.connection, "password", null)
    host                = lookup(var.connection, "host", exoscale_compute_instance.this[count.index].public_ip_address)
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
        file_path  = "${path.module}/ansible-data/instance.yml"
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
  source         = "git::https://github.com/camptocamp/terraform-puppet-node.git?ref=v1.x"
  instance_count = var.puppet == null ? 0 : var.instance_count

  instances = [
    for i in range(length(exoscale_compute_instance.this)) :
    {
      hostname = format("%s.%s", exoscale_compute_instance.this[i].name, var.domain)
      connection = {
        host        = lookup(var.connection, "host", exoscale_compute_instance.this[i].public_ip_address)
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
