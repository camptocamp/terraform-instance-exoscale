terraform {
  required_providers {
    exoscale = {
      source = "exoscale/exoscale"
    }

    aws = {
      source = "hashicorp/aws"
    }

    freeipa = {
      source = "camptocamp/freeipa"
    }

    puppetca = {
      source = "camptocamp/puppetca"
    }

    puppetdb = {
      source = "camptocamp/puppetdb"
    }
  }
}
