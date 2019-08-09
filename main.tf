resource "random_string" "affinity_group_name" {
  length  = 16
  upper   = false
  number  = false
  special = false
}

resource "exoscale_affinity" "affinity_group" {
  name = random_string.affinity_group_name.result
  type = "host anti-affinity"
}

resource "exoscale_nic" "priv_interface" {
  count = var.private_network != null ? var.instance_count : 0

  compute_id = exoscale_compute.this[count.index].id
  network_id = var.private_network.id
  ip_address = cidrhost(var.private_network.cidr, lookup(var.private_network, "offset", 10) + count.index)
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
    filename = "additional.cfg"
    merge_type = "list(append)+dict(recurse_array)+str()"
    content_type = "text/cloud-config"
    content = "${var.additional_user_data}"
  }
}

resource "exoscale_compute" "this" {
  count = var.instance_count

  key_pair = var.key_pair
  display_name = format("%s-%s", var.display_name, count.index)
  disk_size = var.root_disk_size
  security_groups = var.security_groups
  size = var.size
  template = var.template
  zone = var.region
  affinity_groups = [
    exoscale_affinity.affinity_group.name
  ]
  user_data = "${data.template_cloudinit_config.config[count.index].rendered}"

  tags = var.tags

  lifecycle {
    ignore_changes = ["user_data", "security_groups", "key_pair", "affinity_groups", "affinity_group_ids"]
  }
}

#########
# Puppet

module "puppet-node" {
  source = "git::ssh://git@github.com/camptocamp/terraform-puppet-node.git"
  instance_count = var.puppet == null ? 0 : var.instance_count

  instances = [
    for i in range(length(exoscale_compute.this)) :
    {
      hostname = format("%s.%s", exoscale_compute.this[i].name, var.domain)
      connection = {
        host = lookup(var.connection, var.connection.host, exoscale_compute.this[i].ip_address)
        private_key = lookup(var.connection, var.connection.private_key, null)
      }
    }
  ]

  server_address = lookup(var.puppet, "server_address", null)
  server_port = lookup(var.puppet, "server_port", 443)
  ca_server_address = lookup(var.puppet, "ca_server_address", null)
  ca_server_port = lookup(var.puppet, "ca_server_port", 443)
  environment = lookup(var.puppet, "environment", null)
  role = lookup(var.puppet, "role", null)
  autosign_psk = lookup(var.puppet, "autosign_psk", null)
}

##########
# Rancher

module "rancher-host" {
  source = "git::ssh://git@github.com/camptocamp/terraform-rancher-host.git"
  instance_count = var.rancher == null ? 0 : var.instance_count

  instances = [
    for i in range(length(exoscale_compute.this)) :
    {
      hostname = format("%s.%s", exoscale_compute.this[i].name, var.domain)
      agent_ip = exoscale_compute.this[i].ip_address
      connection = {
        host = lookup(var.connection, var.connection.host, exoscale_compute.this[i].ip_address)
        private_key = lookup(var.connection, var.connection.private_key, null)
      }

      host_labels = merge(
        var.rancher != null ? var.rancher.host_labels : {},
        {
          "io.rancher.host.os" = "linux"
          "io.rancher.host.provider" = "openstack"
          "io.rancher.host.region" = var.region
          "io.rancher.host.external_dns_ip" = exoscale_compute.this[i].ip_address
        }
      )
    }
  ]

  environment_id = var.rancher != null ? var.rancher.environment_id : ""

  deps_on = var.puppet != null ? module.puppet-node.this_provisioner_id : []
}
