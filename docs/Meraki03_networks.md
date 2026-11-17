# Step 3 - Configure Networks and Appliance Settings

## Move this step's file into place

As explained earlier, the module is configured (by `yaml_directories = ["data"]`) to deploy only configuration that is in `data` folder. We already prepared the network configuration for you, and it is currently in the 
`data-lab-task/` folder. This folder is never read by Terraform. So in order to deploy the Network as configured, we need to copy or move the network configuration file (`3_networks.nac.yaml`) to `data` folder. You're still in `meraki/` from the previous step:

```sh
mv data-lab-task/3_networks.nac.yaml data/
```

Only once it's in `data/` will `nac plan` show the branch network and MX
appliance being created.

## Open and review the file

This is the largest file in the lab. It introduces the branch network (named
via `!env branch_name` - unique per attendee pod) plus a reference to the
shared `Datacenter` hub network. The hub already exists for the whole pod,
so this file only points at it by name - it doesn't configure it.

For the branch network, `data/3_networks.nac.yaml` configures:

### Where this fits in the data model

Network as Code organizes Meraki configuration into a handful of canonical
elements: organization, network, device, network settings/profiles,
templates, and the three product-specific blocks - appliance, switch,
wireless. This single file already touches four of them - network settings,
one device, and appliance configuration - which is why it's the largest file
in the lab. Templates (the fifth element) don't appear until step 6.

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
data/3_networks.nac.yaml
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


## Semantic validation

### A clean pass

Before deploying anything, validate the file as it is. VLAN 10's
`group_policy_name: Employees` (line 90) matches a `group_policies` entry
actually named `Employees` in this same network, so `nac validate` passes
both layers - including the module's semantic rule, `302`, which checks
exactly this kind of reference (see its source at
`meraki/.terraform/modules/meraki/nac/rules/302_group_policy_references.py`):

```sh
nac validate
```

```text
$ /usr/local/bin/terraform apply -target=module.meraki.local_sensitive_file.model -auto-approve

────────────────────────────────────────────────────────────────────────────────
Render Summary
────────────────────────────────────────────────────────────────────────────────
  ✓ Render: OK (module.meraki.local_sensitive_file.model -> model.yaml)
────────────────────────────────────────────────────────────────────────────────

$ /home/demouser/.local/bin/nac-validate model.yaml

────────────────────────────────────────────────────────────────────────────────
Validation Summary
────────────────────────────────────────────────────────────────────────────────
  ✓ Syntax validation: PASSED (1 files)
  ✓ Semantic validation: PASSED
────────────────────────────────────────────────────────────────────────────────
```

### Try it: a semantic failure

Now introduce a real mistake: change VLAN 10's `group_policy_name` from
`Employees` to `Employeess` (line 90), then run the exact same command
again:

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

    --------------------------------------------------------------------------------
    WHY THIS MATTERS:
    --------------------------------------------------------------------------------

    Appliance VLANs, identity PSKs and SSID device type policies reference a
    group policy of their network by name. A name that matches no group policy
    of the network is silently ignored: the deployment succeeds, but no group
    policy is applied.

    ────────────────────────────────────────────────────────────────────────────────
    RECOMMENDED FIX:
    ────────────────────────────────────────────────────────────────────────────────

    Define the group policy in the same network, or fix the name:
    ...

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
policy applied. Set `group_policy_name` back to `Employees`, and re-run
`nac validate` to confirm it passes again before you deploy.

Rule `302` ships as a single example of what's possible, not the limit of
it. You can write your own rules for whatever your organization cares
about (a naming convention, an approved VLAN range, a required tag), as
Python classes like this one. You don't add them to the module, though:
you put them in a `.rules/` directory in your own project (here
`meraki/.rules/`), and `nac validate` runs them alongside the module's
rules. If you'd rather not write them yourselves, Cisco Services can
develop custom semantic rules for your organization's specific policies.

Note that before Plan and Apply the "Datacenter" network is the only network available in Meraki Dashboard. 

## Plan and Apply

With the file validated, deploy it for real - both commands run from
`meraki/`:

```sh
nac plan
nac apply
```

As in the previous step, `nac apply` applies the `plan.tfplan` saved by
`nac plan` directly - there's no confirmation prompt, so double-check the
plan output first.

!!! tip "Verify in the Dashboard"
    Your branch network now exists. In the left-hand menu, click **Network Datacenter** then select your network
    from the **Network** selector (it's named after your `branch_name`), then look
    at:

    - **The MX**: **Security & SD-WAN > Monitor > Appliance Status**: the
      appliance with your `branch_mx_serial`, its address, and WAN 1/WAN 2
      uplinks.
    - **VLANs and ports**: **Security & SD-WAN > Configure > Addressing &
      VLANs**: the six VLANs (Data, Voice, Iot, PCI, Guest, Infra) with
      their subnets, `Employees` as the group policy on VLAN 10, and under
      **Per-port VLAN Settings** ports 5-6 and 13-14 as trunks with ports
      7-12 disabled.
    - **Site-to-site VPN**: **Security & SD-WAN > Configure > Site-to-site
      VPN**: type **Spoke** with `Datacenter` as the hub, and under **Local
      networks** VPN mode enabled for every VLAN except Guest.
    - **Traffic shaping**: **Security & SD-WAN > Configure > SD-WAN &
      Traffic Shaping**: the uplink bandwidth limits, the three
      uplink-selection policies under **SD-WAN policies**, and the
      traffic shaping rules.
    - **Group policies**: **Network-wide > Configure > Group Policies**:
      `Employees`, `Iot`, and `Voice`.
    - **SNMP, syslog, NetFlow, local status page**: **Network-wide >
      Configure > General**: the local status page enabled under **Device
      configuration**, and under **Reporting** the syslog server
      `3.4.5.6`, SNMP access set to **V3**, and NetFlow sent to
      `4.5.6.7:2055`.

    As before, look but don't change anything - the YAML stays the single
    source of truth.

## Testing it: run `nac test`

With the network deployed, verify it actually landed on the Dashboard. The module's own test templates
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

```text
$ /usr/local/bin/terraform apply -target=module.meraki.local_sensitive_file.model -auto-approve

────────────────────────────────────────────────────────────────────────────────
Render Summary
────────────────────────────────────────────────────────────────────────────────
  ✓ Render: OK (module.meraki.local_sensitive_file.model -> model.yaml)
────────────────────────────────────────────────────────────────────────────────

$ /home/demouser/.local/bin/nac-test -d model.yaml -o tests/results


📄 Merging data model files...
✅ Data model merging completed (< 1s)

🤖 Running Robot Framework tests...

📝 Rendering Robot Framework templates...
🤖 Executing Robot Framework tests...


Initialized logging in /mnt/c/Users/demouser/Desktop/network-as-code/meraki/tests/results/robot_results/pabot_results
Robot Framework remote server at 127.0.0.1:54563 started.
Storing .pabotsuitenames file
2026-11-16 06:01:44.990997 [PID:2317] [0] [ID:0] EXECUTING Robot Results.Config.Networks List
2026-11-16 06:01:47.200859 [PID:2317] [0] [ID:0] PASSED Robot Results.Config.Networks List in 2.2 seconds
3 tests, 3 passed, 0 failed, 0 skipped.
===================================================
Output:  /mnt/c/Users/demouser/Desktop/network-as-code/meraki/tests/results/robot_results/output.xml
XUnit:   
/mnt/c/Users/demouser/Desktop/network-as-code/meraki/tests/results/robot_results/xunit.xml

Log:     
/mnt/c/Users/demouser/Desktop/network-as-code/meraki/tests/results/robot_results/log.html

Report:  
/mnt/c/Users/demouser/Desktop/network-as-code/meraki/tests/results/robot_results/report.html

Finalizing Pabot execution...
Stopping PabotLib process
Robot Framework remote server at 127.0.0.1:54563 stopped.
PabotLib process stopped
Total testing: 2.20 seconds
Elapsed time:  3.44 seconds
Logs flushed successfully.


======================================================================
Combined Test Execution Summary
----------------------------------------------------------------------
3 tests, 3 passed, 0 failed, 0 skipped.
----------------------------------------------------------------------
Dashboard:  /mnt/c/Users/demouser/Desktop/network-as-code/meraki/tests/results/combined_summary.html
Robot:      /mnt/c/Users/demouser/Desktop/network-as-code/meraki/tests/results/robot_results/log.html
xUnit:      /mnt/c/Users/demouser/Desktop/network-as-code/meraki/tests/results/xunit.xml
======================================================================


Total runtime: 4.34s

✅ All tests passed: 3 out of 3 tests
```

The **Dashboard** line in the summary points at the file to open. To see
the pass/fail result in detail, find
`meraki/tests/results/combined_summary.html` in the VS Code Explorer,
right-click it, and select **Open in Integrated Browser**.

## Try it: a failing test

`nac test` compares your intent - the YAML - with what's actually
configured on the Dashboard. See what happens when the two don't match:

1. In `data/3_networks.nac.yaml`, change the network's `notes` (line 14),
   for example:

    ```yaml
    notes: Branch network managed by Network as Code
    ```

2. Run `nac test` - but **don't** apply yet:

    ```sh
    nac test
    ```

    Like `nac validate`, `nac test` first renders your YAML into
    `model.yaml`, then tests the Dashboard against it. This time the test
    **fails**: the model now expects the new notes, but the Dashboard still
    has the old ones. Open `combined_summary.html` again to see which check
    failed.

3. Deploy the change and test again:

    ```sh
    nac validate
    nac plan
    nac apply
    nac test
    ```

    This time all tests pass.

Tests don't replace deploying - they check that what's deployed matches
what you intended. That's why you run `nac test` after every `nac apply`.

---

**← Previous:** [Organization global settings](Meraki02_org_global.md) · **Next:** [Switching](Meraki04_switching.md)
