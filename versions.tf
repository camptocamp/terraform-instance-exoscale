terraform {
  required_providers {
    exoscale = {
      source = "exoscale/exoscale"
    }
    freeipa = {
      source = "camptocamp/freeipa"
      version = "0.7.0"
    }
  }

  required_version = ">= 0.13"
}
