# Step 3 - Configure Networks, VLAN, Appliance Settings

## Deploy Networks

As explained earlier, the module is configured (by `yaml_directories = ["data"]`) to deploy only configuration that is in `data` folder. We already prepared the network configuration for you, and it is currently in the 
`data-lab-task/` folder. This folder is never read by Terraform. So in order to deploy the Network as configured, we need to copy or move the network configuration file (`2_networks.nac.yaml`) to `data` folder. 

```sh
cd meraki
mv data-lab-task/2_networks.nac.yaml data/
```

Only once it's in `data/` will `nac plan` show the branch network and MX
appliance being created.

## Open and review the file

This is the largest file in the lab. It introduces the branch network (named
via `!env branch_name` - unique per attendee pod) plus a reference to the
shared `Datacenter` hub network. The hub already exists for the whole pod,
so this file only points at it by name - it doesn't configure it.

For the branch network, `data/2_networks.nac.yaml` configures:

### Where this fits in the data model

Network as Code organizes Meraki configuration into a handful of canonical
elements: organization, network, device, network settings/profiles,
templates, and the three product-specific blocks - appliance, switch,
wireless. This single file already touches four of them - network settings,
one device, and appliance configuration - which is why it's the largest file
in the lab. Templates (the fifth element) don't appear until step 7.

### Network-level settings

- `product_types`: `appliance`, `switch`, `wireless` - this network will
  eventually host all three product families, even though only the MX exists
  so far.
- `settings`: enables the local status page with its own login
  (`local_page_username`/`local_page_password`, both via `!env`), and
  `named_vlans: true` so appliance VLANs can be referenced by name later.
- `snmp`: an SNMPv3 user and passphrase pulled from `!env`, the same pattern
  used for org-level SNMP in the previous step.
- `syslog_servers` and `netflow`: Switch/Air Marshal/Flows/URL/Wireless/
  Appliance event logs go to `3.4.5.6:514`; NetFlow records go to
  `4.5.6.7:2055`.
- `group_policies`: three named policies - `Employees`, `Voice`, `Iot`. A
  group policy is a different schema element from a VLAN - it's a reusable
  bandwidth/firewall/content-filtering override applied to matched clients,
  not an L3 subnet definition. Here each policy's only job is
  `vlan_tagging`, stamping matched clients into VLAN 10, 20, or 30
  respectively - the policy and the VLAN it tags into are two separate
  objects working together.

### The Appliance (MX) device

One `devices` entry claims the MX by serial (`!env branch_mx_serial`), places
it on the map (`lat`/`lng`/`address`), and configures
`appliance.uplinks_settings` for WAN1 and WAN2 - both enabled, untagged, with
dynamic (DHCP) IPv4 addressing.

### Appliance configuration

Everything under the network's own `appliance:` key is still authored
directly as YAML:

- `vlans`: six VLANs - Data (10), Voice (20), Iot (30), PCI (40), Guest (50),
  and Infra (999) - each with its own `/24` subnet, appliance IP, and DHCP
  server settings. VLAN 10 also sets `group_policy_name: Employees`,
  assigning that group policy to clients on it by default - more on this
  below.
- `vpn_site_to_site_vpn`: this network as an Auto VPN **spoke**, pointed at
  `Datacenter` as its hub, with a per-subnet `use_vpn` flag - every subnet
  rides the VPN except Guest (50), which stays local.
- `ports`: ports 5-6 and 13-14 trunked with VLANs 1,10,20,30,40,50,999
  allowed; ports 7-12 disabled.
- `traffic_shaping`: global bandwidth limits, two custom performance classes
  (`SaaS_Traffic`, `Critical_Apps`), two shaping rules, per-uplink bandwidth
  limits for WAN1/WAN2/cellular, and three `uplink_selection` policies that
  steer VoIP traffic and one specific TCP/443 destination onto WAN2 while
  everything else prefers WAN1.

## What this step configures, at a glance

```text
data/2_networks.nac.yaml
└── networks
    ├── <branch_name>                        (the branch network)
    │   ├── settings, snmp, syslog_servers, netflow
    │   ├── group_policies
    │   │   ├── Employees → VLAN 10
    │   │   ├── Voice     → VLAN 20
    │   │   └── Iot       → VLAN 30
    │   ├── devices
    │   │   └── MX appliance (branch_mx_serial)
    │   │       └── uplinks_settings: WAN1 + WAN2 (DHCP)
    │   └── appliance
    │       ├── vlans: Data(10, → Employees) · Voice(20) · Iot(30) · PCI(40) · Guest(50) · Infra(999)
    │       ├── vpn_site_to_site_vpn: spoke → Datacenter
    │       ├── ports: trunk (5-6, 13-14) · disabled (7-12)
    │       └── traffic_shaping: bandwidth limits, performance classes, uplink selection
    └── Datacenter                           (unmanaged - already exists)
```


## Plan and Apply

With the file reviewed, deploy it for real - both commands run from
`meraki/`:

```sh
nac plan
nac apply
```

As in the previous step, `nac apply` applies the `plan.tfplan` saved by
`nac plan` directly - there's no confirmation prompt, so double-check the
plan output first.

## Validating the deployed network

### A clean pass

VLAN 10's `group_policy_name: Employees` (line 90) matches a
`group_policies` entry actually named `Employees` in this same network, so
`nac validate` passes both layers - including the module's semantic rule,
`302`, which checks exactly this kind of reference (see its source at
`meraki/.terraform/modules/meraki/nac/rules/302_group_policy_references.py`,
mentioned back in [Org and global
settings](Meraki01_org_global.md#semantic-validation-comes-from-the-module-too)):

```sh
nac validate
```

```text
INFO - Verifying rule id 302

────────────────────────────────────────────────────────────────────────────────
Validation Summary
────────────────────────────────────────────────────────────────────────────────
  ✓ Syntax validation: PASSED (1 files)
  ✓ Semantic validation: PASSED
────────────────────────────────────────────────────────────────────────────────
```

### Try it: a semantic failure

Now introduce a real mistake: typo VLAN 10's `group_policy_name` from
`Employees` to `Employeess`, then run the exact same command again:

```sh
nac validate
```

!!! failure "Semantic validation: FAILED"
    ```text
    [RULE 302] Verify group policy references point to defined group policies

    ================================================================================
    UNDEFINED GROUP POLICY
    ================================================================================

    Found 1 violation(s).

    References to undefined group policies:
      • group policy 'Employeess' is not defined in the network
        Path: meraki.domains[name=US].organizations[name=...].networks[name=...].appliance.vlans[vlan_id=10].group_policy_name

    ────────────────────────────────────────────────────────────────────────────────
    Validation Summary
    ────────────────────────────────────────────────────────────────────────────────
      ✓ Syntax validation: PASSED (1 files)
      ✗ Semantic validation: FAILED (1 violation)

        • 1 HIGH severity violation (rules: 302)
    ────────────────────────────────────────────────────────────────────────────────
    ```

Unlike the previous step's syntax failure, this is perfectly legal YAML and
a perfectly legal string - `nac validate` only catches it because rule
`302` cross-checks the reference against the network's own
`group_policies`. A typo like this would otherwise deploy successfully and
silently do nothing: the VLAN would come up fine, just without the group
policy applied. Set `group_policy_name` back to `Employees` when you're
done, and re-run the command to confirm it passes again.

## Testing it: run `nac test`

You already deployed this step above - now verify it actually landed on the
Dashboard. The module's own test templates
(`nac/tests/templates/config/networks_list.robot`, bundled with the
`meraki` module and auto-discovered the same way the schema and rules are)
already have something to check: the network's `name`, `product_types`,
`time_zone`, and `tags`. The `.robot` extension is a hint at the tooling
underneath - `nac test` runs test cases on **Robot Framework**, generated
from **Jinja2** templates against your merged data model, which is why
these are templates rather than plain, static Robot files:

```sh
nac test
```

Open `tests/results/report.html` to see the pass/fail result. Running this
right after deploying, rather than waiting for the full lab, is a useful
habit: the sooner post-deploy drift or a misconfiguration is caught, the
cheaper it is to fix.

---

**← Previous:** [Org and global settings](Meraki01_org_global.md) · **Next:** [Switching](Meraki03_switching.md)
