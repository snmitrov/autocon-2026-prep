module "meraki" {
  source  = "netascode/nac-meraki/meraki"
  version = "0.13.0-beta.1"

  yaml_directories = ["data"]
}
