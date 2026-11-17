# Cheat Sheet

Quick reference for lab access, commands, and YAML syntax used throughout
both parts of the workshop.

## Lab access

| System | Address | Username | Password |
|---|---|---|---|
| Meraki Dashboard | [dashboard.meraki.com](https://dashboard.meraki.com) | *(provided separately)* | *(provided separately)* |
| Starter Repo (public, clone from here) | [github.com/netascode/autocon-6-workshop](https://github.com/netascode/autocon-6-workshop) | - | - |
| GitLab (your project, push here) | [gitlab.198.18.133.103.nip.io/dcloud/autocon-network-as-code-workshop](https://gitlab.198.18.133.103.nip.io/dcloud/autocon-network-as-code-workshop) | dcloud | C1sco12345 |
| Windows Jump Machine (WebRDP) | *(provided via email)* | - | C1sco12345 |
| Windows Jump Machine (RDP client, over VPN) | `198.18.133.36` | `corp\demouser` | C1sco12345 |

### IOS-XE devices

All 4 devices share one set of NETCONF/SSH credentials.

| Device | IP Address |
|---|---|
| Border | 198.18.128.201 |
| Core | 198.18.128.202 |
| Access1 | 198.18.128.204 |
| Access2 | 198.18.128.205 |

- Username: `nac_admin`
- Password: `cisco`

## nac CLI commands

Source `.env` from the repo root, then work in `meraki/` or `ios-xe/`:

```sh
source .env      # in every new terminal
cd meraki        # or ios-xe
nac setup        # first time only: check prerequisites
nac init         # first time only: download the module and providers
nac validate     # syntax and semantic validation
nac plan         # dry run: what would change
nac apply        # apply the saved plan (no confirmation prompt)
nac test         # test the deployed configuration
```

`nac destroy` deletes what you've deployed - read the warning in
[Meraki step 6](Meraki06_templates.md#clean-up-run-nac-destroy) for exactly
what it removes before using it.

## Environment variables

Set in `.env` (copy from `.env.example`, never commit the real file).

| Variable | Used for |
|---|---|
| `MERAKI_API_KEY` | Meraki Dashboard API auth |
| `org_name` | `!env org_name` - Meraki organization name |
| `branch_name` | `!env branch_name` - your pod's unique network name |
| `branch_mx_serial` / `branch_ms_serial` / `branch_cw_serial` | Appliance/switch/wireless device serials for your pod |
| `IOSXE_USERNAME` / `IOSXE_PASSWORD` | Shared NETCONF/SSH credentials for all 4 IOS-XE devices (username `nac_admin`) |
| `MERAKI_RETRY_ON_ERROR_CODES` / `MERAKI_RETRIES` | Retry temporary Dashboard API errors - preset, no change needed |

See `meraki/README.md` and `ios-xe/README.md` for the complete variable
lists, including the non-secret example credentials (SNMP, RADIUS, local
status page, etc.).

## GitLab CI/CD variables

The pipeline doesn't read `.env`. It needs these six values as CI/CD
variables in your GitLab project (**Settings > CI/CD > Variables**) - see
[step 7](Meraki07_cicd.md#add-your-cicd-variables) for how to add them.
Leave **Protect variable** unticked for all of them, and mask
`MERAKI_API_KEY`.

| Variable | Value |
|---|---|
| `MERAKI_API_KEY` | your personal Meraki Dashboard API key (masked) |
| `org_name` | your workshop's Meraki organization name |
| `branch_name` | your pod's unique network name |
| `branch_mx_serial` | your pod's MX appliance serial |
| `branch_ms_serial` | your pod's MS switch serial |
| `branch_cw_serial` | your pod's CW access point serial |

## Git and GitLab

One-time setup and the first push are in
[Meraki step 7](Meraki07_cicd.md#connect-your-repo-to-gitlab). After that,
every change takes the same route:

```sh
git checkout main && git pull         # start from the latest main
git checkout -b my-change             # new feature branch
git add meraki/
git commit -m "Describe the change"
git push -u origin my-change          # output links to "create merge request"
```

Where to find things in GitLab:

| What | Where |
|---|---|
| CI/CD variables | **Settings > CI/CD > Variables** |
| Merge requests | **Code > Merge requests** |
| Pipelines, job logs, artifacts | **Build > Pipelines**, then click a pipeline and a job |
| Plan summary for a merge request | merge request **Overview** tab |
| Test results | pipeline **Tests** tab |

## YAML syntax quick reference

- **`!env VAR_NAME`** - resolves to the value of environment variable
  `VAR_NAME` at apply time. Keeps secrets and pod-specific values (like
  `branch_name`) out of version control while the YAML structure stays
  stable.
- **Deep merge** - the `nac-*` Terraform modules read every YAML file under
  `data/` and deep-merge them into one model. Dictionaries merge key by key;
  two list entries merge into one when all the scalar attributes they share
  have equal values (typically the same `name`), otherwise both are kept.
  Two files both containing `name: !env branch_name` merge into a single
  object instead of producing two.
- **File naming is reading order, not deployment order** - numeric prefixes
  (`2_`, `3_`, `4_`...) match the lab steps; Terraform builds its
  own dependency graph from the merged model regardless of file name.
- **`${VARIABLE}`** - template-style placeholders (e.g. `${HOSTNAME}`,
  `${SITE}`) resolved from `variables:` blocks defined at the global,
  device-group, or device level, with device-level taking precedence.

---

**← Previous:** [Part 2 - IOS-XE: Templates](IOSXE04_templates.md) · **Next:** [Topologies](Topologies.md)
