# AutoCon 6 – Meraki Network-as-Code Lab

## Overview

This folder deploys a single-branch Meraki network (appliance, switch,
wireless) using the
[Network as Code for Meraki module](https://registry.terraform.io/modules/netascode/nac-meraki/meraki)
(`netascode/nac-meraki/meraki`), driven entirely by YAML under `data/`.

The module reads **every** `*.yaml` file in `data/`, deep-merges them into a
single model, and applies the result. Dictionaries merge key by key; list
entries merge when the scalar attributes they share all have the same value
(in practice usually the same `name`). This means:

- File names and the order files are read in have **no effect** on the
  resulting configuration or on the actual apply order — Terraform builds its
  own resource dependency graph from the merged model.
- The `2_`, `3_`, `4_`... prefixes on the files match the step numbers in the
  lab guide (step 1 is logging in, so there is no `1_` file). They are purely
  a **reading / teaching order** — a suggested path from "org and network
  basics authored as direct YAML" to "the templating pattern" at the end, not
  a staged deployment mechanism. The two `6_` files share a prefix on
  purpose: the template library and the file that applies it are a matched
  pair and are always moved (and deployed) together.
- `data/` starts empty (only a `.gitkeep`). All of the lab's files live in
  `data-lab-task/` until it's their turn — attendees move (not copy) each
  file from `data-lab-task/` into `data/` as they reach that step in the lab
  guide. `data-lab-task/` is never read; it's a staging area, not a second
  copy of the deployed model.

## Prerequisites

- [`nac-cli`](https://pypi.org/project/nac-cli/) (`uv tool install nac-cli`)
  and Terraform. `nac setup` checks both and reports the resolved tool
  versions; the Meraki provider and the module are downloaded by `nac init`.
- An `.env` (copied from `../.env.example`) or exported shell variables with:
  - `MERAKI_API_KEY` — your Meraki Dashboard API key
  - `MERAKI_RETRY_ON_ERROR_CODES=404` — retries the temporary 404s the
    Dashboard API can return right after a device is claimed
  - `MERAKI_RETRIES=5` — retries those calls up to 5 times instead of the
    default 3
  - the `!env`-tagged values referenced across the YAML files:
    - `org_name`
    - `branch_name`
    - `branch_mx_serial`, `branch_ms_serial`, `branch_cw_serial`
    - `local_page_username`, `local_page_password`
    - `snmp_username`, `snmp_passphrase`
    - `v3_auth_pass`, `v3_priv_pass`
    - `radius_server_secret`, `radius_accounting_server_secret`

## Files and what they introduce

| File | Introduces |
|---|---|
| `2_org_global.nac.yaml` | Org-wide settings: `login_security` policy and org-level SNMP (v3). |
| `3_networks.nac.yaml` | The branch network (named via `!env branch_name` — unique per attendee pod) and the unmanaged hub network. Covers network-level basics (product types, time zone, tags, local status page, SNMP, syslog, NetFlow, group policies), the MX appliance device, and appliance config authored directly as YAML: `appliance.vlans`, `appliance.vpn_site_to_site_vpn` (spoke config), `appliance.ports`, and `appliance.traffic_shaping`. |
| `4_switching.nac.yaml` | The MS switch device per branch, with per-port-range overrides (uplink trunk, infra access ports disabled by default, AP trunk, end-user access ports with voice VLAN), switch-wide settings (management VLAN, MTU, QoS, storm control), and the wired 802.1X access policy. Depends conceptually on the VLANs defined in step 3. |
| `5_wireless.nac.yaml` | The CW access point device per branch (claimed with tags/location only — no RF profile reference, see the known gotcha below) plus network-level `wireless.rf_profiles` and `wireless.ssids` (`Data` 802.1X/RADIUS SSID, `Guest` open/splash-page SSID). |
| `6_appliance_templates.nac.yaml` + `6_appliance_variables.nac.yaml` | The templating pattern, as a paired step. `6_appliance_templates.nac.yaml` is the template library (`app_fw` firewall rules, `app_content` content filtering, `app_intrusion` intrusion prevention, `app_mal` malware protection); `6_appliance_variables.nac.yaml` applies those templates to the branch network via `templates:`. |

## Running the lab

All commands run from this folder, after `source ../.env`:

```sh
nac setup      # once: check prerequisites
nac init       # once: download the module and the Meraki provider
nac validate   # syntax + semantic validation
nac plan       # preview the changes (saved to plan.tfplan)
nac apply      # apply the saved plan - no confirmation prompt
nac test       # post-deployment tests against the live Dashboard
```

`nac` drives Terraform, `nac-validate`, and `nac-test` for you — there's no
need to call any of them directly. `nac validate` and `nac test` first
render the merged model to `model.yaml` (as configured in the module's
`.terraform/modules/meraki/nac/manifest.yaml`); `nac apply` keeps it up to
date as part of the apply.

The whole merged model is applied in one pass — Terraform resolves the
dependency graph itself (e.g. VLANs before the appliance ports that
reference them, RF profiles before devices that reference them).

### Known gotcha: wireless RF profile dependency

Early testing hit a `meraki_wireless_radio_settings` error on first apply:
`None of the fields (rfProfileId, twoFourGhzSettings, fiveGhzSettings) were specified`.
This happens when a device's `wireless.radio_settings.rf_profile_name`
reference resolves before its RF profile (and the profile's SSID
dependencies) exist in state. The AP device in `5_wireless.nac.yaml`
therefore omits `wireless.radio_settings`. If you add it back for per-device
RF profile assignment and hit the error, run `nac plan` and `nac apply` a
second time.

## Notes on file ordering vs. apply order

Worth repeating since it's easy to assume otherwise: renaming or reordering
files under `data/` is a **documentation aid only**. The module merges all
YAML in the directory into one model before anything is applied, so:

- Moving a block between files (e.g. the AP device from `5_wireless.nac.yaml`
  to `3_networks.nac.yaml`) changes nothing about what gets deployed.
- The only thing that determines the real apply order is Terraform's own
  resource dependency graph.

## Validation and testing

Both come with the module — there's no schema, rule, or test file to
maintain in this folder. After `nac init`, they live under
`.terraform/modules/meraki/nac/`:

- `schema.yaml` and `rules/` — the schema and semantic rules `nac validate`
  checks the model against (for example rule `302`, which verifies that
  group policy references point to defined group policies). Your own rules
  go into a `.rules/` folder here, and `nac validate` runs them alongside the
  module's.
- `tests/templates/` — the Robot Framework test templates `nac test` renders
  against the model and runs against the live Dashboard
  (`config/networks_list.robot` verifies each network's name, product types,
  tags, time zone, and notes). Results go to `tests/results/`; open
  `tests/results/combined_summary.html` for the summary.
