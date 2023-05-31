variable "instance_count" {
  default = 1
  type    = number
}

variable "ssh_key" {
  type = string
}

variable "security_group_ids" {
  type    = list(string)
  default = []
}

variable "security_group_rules" {
  type = map(object({
    type        = string
    description = string
    protocol    = string
    cidr        = string
    start_port  = number
    end_port    = number
  }))
  default = {}
}

variable "hostname" {
  type    = string
  default = ""
}

variable "type" {
  type = string
}

variable "template" {
  type = string
}

variable "additional_user_data" {
  type    = string
  default = "#cloud-config\n"
}

variable "additional_user_script" {
  type    = string
  default = "#! /bin/sh"
}

variable "domain" {
  type = string
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
  default = {}
}

variable "ansible_check" {
  type    = bool
  default = false
}

#########
# Puppet

variable "puppet" {
  type    = map(string)
  default = null
}

#########
# FreeIPA

variable "freeipa" {
  type    = map(string)
  default = null
}
