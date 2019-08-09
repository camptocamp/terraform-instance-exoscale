variable "instance_count" {
  default = 1
  type    = number
}

variable "key_pair" {
  type = string
}

variable "security_groups" {
  type    = list(string)
  default = []
}

variable "display_name" {
  type = string
}

variable "size" {
  type = string
}

variable "template" {
  type = string
}

variable "additional_user_data" {
  type    = string
  default = "#cloud-config\n"
}

variable "domain" {
  type = string
}

variable "zone" {
  type    = string
  default = ""
}

variable "region" {
  type = string
}

variable "root_disk_size" {
  type    = number
  default = 10
}

variable "private_network" {
  type = object({
    id     = string
    name   = string
    cidr   = string
    offset = number
  })
  default = null
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "connection" {
  type    = map(string)
  default = null
}

##########
# Rancher

variable "rancher" {
  type = object({
    environment_id = string
    host_labels    = map(string)
  })
  default = null
}

#########
# Puppet

variable "puppet" {
  type    = map(string)
  default = null
}
