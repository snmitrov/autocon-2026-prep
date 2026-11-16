# terraform {
#   backend "http" {
#     skip_cert_verification = true
#   }
# }

module "iosxe" {
  source  = "netascode/nac-iosxe/iosxe"
  version = "1.1.0-beta.1"

  yaml_directories   = ["data"]
  device_transaction = true
}

# State: GitLab-managed remote state via the `http` backend above. The
# backend has no address here on purpose — it's entirely configured via
# TF_HTTP_* environment variables set in ios-xe/.gitlab-ci.yml, so no
# local terraform.tfstate file or GitLab CI `cache:` key is needed.

