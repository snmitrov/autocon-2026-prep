module "iosxe" {
  source  = "netascode/nac-iosxe/iosxe"
  version = "1.1.0-beta.1"

  yaml_directories = ["data"]
}
