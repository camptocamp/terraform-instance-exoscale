terraform {
  required_providers {
    exoscale = {
      source = "exoscale/exoscale"
    }
    freeipa = {
      source  = "camptocamp/freeipa"
    }
  }

  required_version = ">= 0.13"
}
