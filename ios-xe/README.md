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
- The `1_`, `2_`, `3_`... prefixes on the files in `data/` are purely a
  **reading / teaching order** — a suggested path from "global settings and
  per-device identity/uplinks" to "the templating/indirection pattern" at the
  end, not a staged deployment mechanism. The two `4_` files share a prefix on
  purpose: the template library and the device group that applies it are a
  matched pair and are always read (and deployed) together.

The `netascode/nac-iosxe` provider (`CiscoDevNet/iosxe`) talks to devices over
**NETCONF only** (no RESTCONF) — each device must have `netconf-yang` enabled.

## Deployment order

| File | Introduces |
|---|---|
| `data/1_global.nac.yaml` | Global settings shared by every device: the `${SITE}` variable, a login banner that references both `${SITE}` and the per-device `${HOSTNAME}` variable, and `system.hostname` set from `${HOSTNAME}`. |
| `data/devices/*.nac.yaml` | Per-device registration (`name`, `host`) and the `HOSTNAME` variable that resolves the global banner/hostname template for that device. |
| `data/3_device_groups.nac.yaml` | One device group, `ACCESS_SWITCHES` (`Access1`, `Access2`), grouping the two access-layer switches for config shared between them. Depends conceptually on the devices defined in the previous step. |
| `data/4_templates.nac.yaml` + `data/4_templates_assignment.nac.yaml` | Introduces the templating/indirection pattern, as a paired step — deployed together since one is meaningless without the other. `4_templates.nac.yaml` is the template library (`access_switch_vlans`, a `type: model` template defining VLANs 10/DATA, 20/VOICE, 99/MGMT); `4_templates_assignment.nac.yaml` applies that template to the `ACCESS_SWITCHES` device group by matching `name: ACCESS_SWITCHES`, merging into the group defined in step 3. |

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

## Applying the configuration

```sh
terraform init
terraform plan
terraform apply
```

## Testing

- `rules/` holds [`nac-validate`](https://github.com/netascode/nac-validate) semantic
  rules (e.g. `201_unique_device_host.py` blocks two devices sharing the same
  `host`/management IP):

  ```sh
  pip install nac-validate
  nac-validate -r rules data/**/*.nac.yaml
  ```

- `tests/templates/` holds a [`nac-test`](https://github.com/netascode/nac-test)
  Robot Framework suite that connects to each live device over NETCONF and checks
  it against the YAML model (`devices/hostname.robot` verifies the device's
  configured hostname matches `devices[].variables.HOSTNAME`). The NETCONF
  transport (`tests/templates/iosxe_netconf.py`) uses the `ncclient` package,
  which isn't one of `nac-test`'s own dependencies and needs installing
  separately:

  ```sh
  pip install ncclient
  ```

  It authenticates with the same `IOSXE_USERNAME` / `IOSXE_PASSWORD` /
  `IOSXE_INSECURE` env vars as the Terraform provider (see Prerequisites above).
  Needs the merged model written to disk first:

  ```sh
  terraform apply -target=module.iosxe.local_sensitive_file.model -auto-approve
  nac-test -d ./model.yaml -t ./tests/templates -o ./tests/results
  ```
