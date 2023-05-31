output "this_compute_public_ip_address" {
  value = exoscale_compute_instance.this.*.public_ip_address
}

######
# API

output "this_instance_public_ipv4" {
  description = "Instance's public IPv4"
  value       = exoscale_compute_instance.this.*.public_ip_address
}

output "this_instance_public_ipv6" {
  description = "Instance's public IPv6"
  value       = exoscale_compute_instance.this.*.ipv6_address
}

output "this_instance_hostname" {
  description = "Instance's hostname"
  value = [
    for instance_name in exoscale_compute_instance.this[*].name :
    format("%s.%s", instance_name, var.domain)
  ]
}

output "this_instance_private_ipv4" {
  description = "Instance's private IPv4"
  value = var.private_network != null ? [
    for i in range(var.instance_count) :
    cidrhost(var.private_network.cidr, var.private_network.offset + i)
  ] : null
}

output "this_instance_id" {
  description = "Instance's ID"
  value       = exoscale_compute_instance.this.*.id
}
