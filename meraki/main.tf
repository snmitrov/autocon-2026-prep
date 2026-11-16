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
  source           = "netascode/nac-meraki/meraki"
  version          = "0.13.0-beta.1"
  yaml_directories = ["data"]
}

