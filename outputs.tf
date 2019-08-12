output "this_compute_ip_address" {
  value = exoscale_compute.this.*.ip_address
}

######
# API

output "this_instance_public_ipv4" {
  description = "Instance's public IPv4"
  value       = exoscale_compute.this.*.ip_address
}

output "this_instance_public_ipv6" {
  description = "Instance's public IPv6"
  value       = exoscale_compute.this.*.ip6_address
}

output "this_instance_hostname" {
  description = "Instance's hostname"
  value = [
    for instance_name in exoscale_compute.this[*].name :
    format("%s.%s", instance_name, var.domain)
  ]
}

output "this_instance_private_ipv4" {
  description = "Instance's private IPv4"
  value = exoscale_nic.priv_interface.*.ip_address
}
