terraform {
  # backend "http" {
  #   skip_cert_verification = true
  # }
  required_providers {
    meraki = {
      source = "CiscoDevNet/meraki"
    }
  }
}

provider "meraki" {
  retry_on_error_codes = [404, 400, 401]
}

module "meraki" {
  source           = "github.com/netascode/terraform-meraki-nac-meraki?ref=v0.13.0-beta.1"
  yaml_directories = ["data"]
}

