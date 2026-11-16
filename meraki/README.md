# AutoCon 6 – Meraki Network-as-Code Lab

## Overview

This repo deploys a single-branch Meraki network (appliance, switch, wireless)
using the [`terraform-meraki-nac-meraki`](https://github.com/netascode/terraform-meraki-nac-meraki)
module, driven entirely by YAML under `data/`.

The module reads **every** `*.yaml` file in `data/`, deep-merges them into a single
model (matching on `name` at each nesting level), and applies the result. This means:

- File names and the order files are read in have **no effect** on the resulting
  configuration or on Terraform's actual apply order — Terraform builds its own
  resource dependency graph from the merged model.
- The `1_`, `2_`, `3_`... prefixes on the files in `data/` are purely a **reading /
  teaching order** — a suggested path for walking through the configuration from
  "org and network basics authored as direct YAML" to "the templating/indirection
  pattern" at the end, not a staged deployment mechanism. The two `5_` files share
  a prefix on purpose: the template library and the templates that apply it are a
  matched pair and are always read (and deployed) together.
- `data/` starts with only `1_org_global.nac.yaml` in place. The rest of the
  lab's files live in `data-lab-task/` until it's their turn — attendees move
  (not copy) each file from `data-lab-task/` into `data/` as they reach that
  step in the lab guide. `data-lab-task/` is never read by Terraform; it's a
  staging area, not a second copy of the deployed model.

## Prerequisites

- Terraform >= 1.x and the [Meraki provider](https://registry.terraform.io/providers/CiscoDevNet/meraki/latest)
  configured with an API key (`MERAKI_DASHBOARD_API_KEY` env var).
- An `.env` (or exported shell vars) providing the `!env`-tagged values referenced
  across the `data/*.yaml` files, e.g.:
  - `org_name`
  - `branch_name`
  - `branch_mx_serial`, `branch_ms_serial`, `branch_cw_serial`
  - `local_page_username`, `local_page_password`
  - `snmp_username`, `snmp_passphrase`
  - `v3_auth_pass`, `v3_priv_pass`
  - `radius_server_secret`, `radius_accounting_server_secret`

## Deployment order

| File | Introduces |
|---|---|
| `data/1_org_global.nac.yaml` | Org-wide settings: admin, `login_security` policy, org-level SNMP (v3), and the org-wide `appliance.vpn_firewall_rules` shared by every spoke via the hub. |
| `data/2_networks.nac.yaml` | The branch network (named via `!env branch_name` — unique per attendee pod) and the unmanaged hub network. Covers network-level basics (product types, time zone, tags, local status page, SNMP, syslog, NetFlow, group policies), the MX appliance device, and appliance config authored directly as YAML: `appliance.vlans`, `appliance.vpn_site_to_site_vpn` (spoke config), `appliance.ports`, and `appliance.traffic_shaping`. |
| `data/3_switching.nac.yaml` | The MS switch device per branch, with per-port-range overrides (uplink trunk, infra access ports disabled by default, AP trunk, end-user access ports with voice VLAN), switch-wide settings (management VLAN, MTU, QoS, storm control), and the wired 802.1X access policy. Depends conceptually on the VLANs defined in step 2. |
| `data/4_wireless.nac.yaml` | The CW access point device per branch (claimed with tags/location only — no RF profile reference, to avoid a known apply-ordering issue, see below) plus network-level `wireless.rf_profiles` and `wireless.ssids` (`Data` 802.1X/RADIUS SSID, `Guest` open/splash-page SSID). |
| `data/5_appliance_templates.nac.yaml` + `data/5_appliance_variables.nac.yaml` | Introduces the templating/indirection pattern, as a paired step — deployed together since one is meaningless without the other. `5_appliance_templates.nac.yaml` is the template library (`app_fw`, `app_content`, `app_intrusion`, `app_mal`); `5_appliance_variables.nac.yaml` applies those templates to each branch network via `templates:`. Read both together once the direct-YAML pattern from steps 1-4 is already familiar. |

## Applying the configuration

Standard single-pass apply:

```sh
terraform init
terraform plan
terraform apply
```

This applies the entire merged model in one pass — Terraform resolves the
dependency graph itself (e.g. VLANs before the appliance ports that reference
them, RF profiles before devices that reference them).

### Optional: staged apply for troubleshooting

If you hit a dependency-ordering error (see Known gotcha below), you can stage
the apply with `-target` to force resources to be created in a specific order.
`-target` automatically pulls in anything the targeted resource depends on, so
you can, for example, apply the network and appliance config first, then the
rest:

```sh
terraform apply -target=module.meraki.meraki_network.networks
terraform apply
```

### Known gotcha: wireless RF profile dependency

Early testing hit a `meraki_wireless_radio_settings` error on first apply:
`None of the fields (rfProfileId, twoFourGhzSettings, fiveGhzSettings) were specified`.
This happens when a device's `wireless.radio_settings.rf_profile_name` reference
resolves before its RF profile (and the profile's SSID dependencies) exist in
state — the module's lookup silently falls back to `null` instead of erroring
clearly. The AP devices in `data/4_wireless.nac.yaml` currently omit
`wireless.radio_settings` to avoid this; add it back (and use the staged apply
above, or simply re-run `terraform apply` a second time) if you want per-device
RF profile assignment.

## Notes on file ordering vs. Terraform apply order

Worth repeating since it's easy to assume otherwise: renaming/reordering files
under `data/` is a **documentation aid only**. The nac module merges all YAML
in the directory into one model before Terraform ever runs, so:

- Moving a block between files (e.g. the AP devices from `2_networks.nac.yaml`
  to `4_wireless.nac.yaml`) changes nothing about what gets deployed.
- The only things that determine real apply order are Terraform's own resource
  dependency graph and, if used, explicit `-target` flags.

## Testing

- `.rules/` holds [`nac-validate`](https://github.com/netascode/nac-validate) semantic
  rules (e.g. `101_admin_name.py` blocks an org administrator named `root`).
  `nac-validate` auto-discovers both `.schema.yaml` and `.rules/` from the
  current directory, no flags needed:

  ```sh
  pip install nac-validate
  nac-validate data/*.nac.yaml
  ```

- `tests/templates/` holds a [`nac-test`](https://github.com/netascode/nac-test)
  Robot Framework suite that queries the live Meraki Dashboard API and checks it
  against the YAML model (`config/networks_list.robot` verifies each network's
  `name`, `product_types`, `time_zone`, and `tags`). Needs `MERAKI_API_KEY` set
  and the merged model written to disk first:

  ```sh
  terraform apply -target=module.meraki.module.model -auto-approve
  nac-test -d ./meraki_merged_configuration.nac.yaml -t ./tests/templates -o ./tests/results
  ```

