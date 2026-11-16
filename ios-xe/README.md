# AutoCon 6 – IOS-XE Network-as-Code Lab

## Overview

This folder configures the 4 IOS-XE devices in the `autocon-xe-01-catalog`
lab topology (`Border`, `Core`, `Access1`, `Access2`) using the
[`netascode/nac-iosxe`](https://registry.terraform.io/modules/netascode/nac-iosxe/iosxe/latest)
module, driven entirely by YAML under `data/`. Two Alpine Linux hosts
(`Host1`, `Host2`) complete the topology end-to-end but aren't IOS-XE devices,
so they have no Terraform/YAML representation here — see the Devices table
below for the full addressing plan.

The module reads **every** `*.yaml` file in `data/`, deep-merges them into a
single model (matching on `name` at each nesting level), and applies the
result. This means:

- File names and the order files are read in have **no effect** on the
  resulting configuration or on Terraform's actual apply order — Terraform
  builds its own resource dependency graph from the merged model.
- The `2_`, `3_`, `4_`... prefixes on the files match the step numbers in the
  lab guide (step 1 is SSH access, so there is no `1_` file). They are purely
  a **reading / teaching order** — a suggested path from "global settings and
  per-device identity" to "the templating pattern" at the end, not a staged
  deployment mechanism. The two `5_` files share a prefix on purpose: the
  template library and the file that applies it are a matched pair and are
  always moved (and deployed) together.
- `data/` starts empty (only a `.gitkeep`). All of the lab's files live in
  `data-lab-task/` until it's their turn — attendees move each file into
  `data/` as they reach that step.

The `netascode/nac-iosxe` provider (`CiscoDevNet/iosxe`) talks to devices over
**NETCONF only** (no RESTCONF) — each device must have `netconf-yang` enabled.

## Deployment order

| File | Introduces |
|---|---|
| `data/2_global.nac.yaml` | Global settings shared by every device: the `${SITE}` variable, a login banner that references both `${SITE}` and the per-device `${HOSTNAME}` variable, and `system.hostname` set from `${HOSTNAME}`. |
| `data/2_inventory.nac.yaml` | Device inventory: each device's `name`, `host`, and the `HOSTNAME` variable that resolves the global banner and hostname for that device. |
| `data/2_border.nac.yaml` | Configuration for `Border` only - a prefix list and a route map that matches on it - merged into the inventory entry by `name`. It's a lab example, not a complete routing policy, there to exercise the module's rule `313` and its prefix-list test. |
| `data/3_device_groups.nac.yaml` | One device group, `ACCESS_SWITCHES` (`Access1`, `Access2`), grouping the two access-layer switches for config shared between them. Depends conceptually on the devices defined in the previous step. |
| `data/4_templates.nac.yaml` + `data/4_vlan_groups.nac.yaml` | The templating pattern, as a paired step. `4_templates.nac.yaml` defines one `type: model` template, `vlan`, whose ID and name come from the `${VLAN_ID}` and `${VLAN_NAME}` variables. `4_vlan_groups.nac.yaml` creates one device group per VLAN (`VLAN_DATA` 10, `VLAN_MGMT` 99) that lists the devices to deploy it to, references the template, and sets the variables. |

## Topology

```
Host1 ── Access1 ──┐
                    ├── Core ── Border
Host2 ── Access2 ──┘
```

`Border` and `Core` form the fabric's L3 core; `Access1`/`Access2` are the
access-layer switches each hosting one Alpine Linux end host for
connectivity testing. No interface/uplink wiring is encoded in the YAML
yet — only device identity (`name`/`host`/`HOSTNAME`) is currently modeled.

## Prerequisites

- Terraform >= 1.9 and the [IOS-XE provider](https://registry.terraform.io/providers/CiscoDevNet/iosxe/latest)
  (fetched automatically as a dependency of the `nac-iosxe` module).
- All 4 IOS-XE devices share one set of SSH credentials, set via the
  provider's environment variables:
  - `IOSXE_USERNAME` (`nac_admin` in this lab)
  - `IOSXE_PASSWORD`
  - Optionally `IOSXE_INSECURE=true` to skip SSH host-key verification (useful
    for CML-hosted lab nodes); this is already the provider default.

## Devices

| Node | Role | IP Address | Interface | Managed by Terraform |
|---|---|---|---|---|
| Border | cat9000v-q200 | 198.18.128.201/18 | Vlan1 (mgmt, via Gi0/0) | Yes |
| Core | cat9000v-q200 | 198.18.128.202/18 | Vlan1 (mgmt, via Gi0/0) | Yes |
| Host1 | alpine | 198.18.128.203/18 | eth0 | No |
| Access1 | cat9000v-q200 | 198.18.128.204/18 | Vlan1 (mgmt, via Gi0/0) | Yes |
| Access2 | cat9000v-q200 | 198.18.128.205/18 | Vlan1 (mgmt, via Gi0/0) | Yes |
| Host2 | alpine | 198.18.128.206/18 | eth0 | No |

All on VLAN1, subnet `198.18.128.0/18`, default route via gateway
`198.18.128.1`, reachable through the CML "System Bridge" external connector.

## Running the lab

All commands run from this folder, after `source ../.env`:

```sh
nac setup      # once: check prerequisites
nac init       # once: download the module and the IOS XE provider
nac validate   # syntax + semantic validation
nac plan       # preview the changes (saved to plan.tfplan)
nac apply      # apply the saved plan - no confirmation prompt
nac test       # post-deployment tests against the live devices
```

`nac` drives Terraform, `nac-validate`, and `nac-test` for you — there's no
need to call any of them directly.

## Validation and testing

Both come with the module — there's no schema, rule, or test file to
maintain in this folder. After `nac init`, they live under
`.terraform/modules/iosxe/nac/`:

- `schema.yaml` and `rules/` — the schema and semantic rules `nac validate`
  checks the model against. Your own rules go into a `.rules/` folder here,
  and `nac validate` runs them alongside the module's.
- `tests/templates/` — the Robot Framework test templates `nac test` renders
  against the model and runs against the live devices. Results go to
  `tests/results/`; open `tests/results/combined_summary.html` for the
  summary.
