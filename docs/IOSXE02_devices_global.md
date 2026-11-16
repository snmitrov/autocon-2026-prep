# Step 2 - Configure Devices and Global Settings

## Move this step's files into place

As in the Meraki part, `ios-xe/data/` starts empty and each step's files
wait in `ios-xe/data-lab-task/` until it's that step's turn. This step uses
three: the device inventory, the `Border`-specific configuration, and the
global settings. From the repository root:

```sh
mv ios-xe/data-lab-task/2_inventory.nac.yaml ios-xe/data/
mv ios-xe/data-lab-task/2_border.nac.yaml ios-xe/data/
mv ios-xe/data-lab-task/2_global.nac.yaml ios-xe/data/
```

## Open and review the files

### Inventory

`data/2_inventory.nac.yaml` registers all four devices - each with its
`name`, its management IP as `host`, and one variable, `HOSTNAME`:

```yaml
---
iosxe:
  devices:
    - name: Border
      host: 198.18.128.201
      variables:
        HOSTNAME: Border
    - name: Core
      host: 198.18.128.202
      variables:
        HOSTNAME: Core
    - name: Access1
      host: 198.18.128.204
      variables:
        HOSTNAME: Access1
    - name: Access2
      host: 198.18.128.205
      variables:
        HOSTNAME: Access2
```

### Configuration for a single device

`data/2_border.nac.yaml` adds configuration for `Border` only: a prefix list
and a route map that matches on it. Settings under a device's
`configuration:` apply to that device only - the top level of the device >
device group > global precedence. The file doesn't repeat the host or
variables: its `name: Border` entry deep-merges into the `Border` entry from
the inventory, so the two files end up describing one device.

```yaml
---
iosxe:
  devices:
    - name: Border
      configuration:
        prefix_lists:
          - name: PL_LAB_MGMT
            seqs:
              - seq: 10
                action: permit
                prefix: 198.18.128.0/18
        route_maps:
          - name: RM_LAB_MGMT
            entries:
              - seq: 10
                operation: permit
                match:
                  ipv4_address_prefix_lists:
                    - PL_LAB_MGMT
```

!!! note "Not a complete configuration"
    The prefix list and route map are a lab example, not a working routing
    policy - nothing in the lab uses `RM_LAB_MGMT`. They're here to show
    configuration for a single device.

### Global settings

Global configuration applies to **every** registered device unless
overridden at the device-group or device level - the precedence hierarchy is
device > device group > global. `data/2_global.nac.yaml` defines:

- A **global variable**, `${SITE}`, set once and inherited by all four
  devices.
- A login banner and `system.hostname` that both reference `${HOSTNAME}` -
  the per-device variable from the inventory above. The same global
  configuration therefore resolves to a different hostname on each device.

```yaml
---
iosxe:
  global:
    variables:
      SITE: "AutoCon 6 IOS XE Lab"
    configuration:
      banner:
        login: |-
          #########################################
          #   Welcome to the AutoCon IOS XE Lab!  #
          #########################################
          Site:   ${SITE}
          Device: ${HOSTNAME}
      system:
        hostname: ${HOSTNAME}
```

Variables let you write one banner instead of four: the hostname is defined
once per device and used in two places - the banner text and the `hostname`
command.

## Initialize with `nac setup` and `nac init`

The IOS-XE track has its own working directory, so it needs its own
initialization. Your `.env` already holds the device credentials
(`IOSXE_USERNAME`, `IOSXE_PASSWORD`). From the repository root, source it
again if you're in a new terminal, then switch to `ios-xe/`:

```sh
source .env
cd ios-xe
nac setup
nac init
```

`nac setup` should show a ✓ on every line, as in the Meraki part. `nac init`
downloads the IOS XE module and the `CiscoDevNet/iosxe` provider. From here
on, all commands run from `ios-xe/`.

## Validate

```sh
nac validate
```

```text
$ /usr/local/bin/terraform apply -target=module.iosxe.local_sensitive_file.model -auto-approve

────────────────────────────────────────────────────────────────────────────────
Render Summary
────────────────────────────────────────────────────────────────────────────────
  ✓ Render: OK (module.iosxe.local_sensitive_file.model -> model.yaml)
────────────────────────────────────────────────────────────────────────────────

$ /home/demouser/.local/bin/nac-validate model.yaml

────────────────────────────────────────────────────────────────────────────────
Validation Summary
────────────────────────────────────────────────────────────────────────────────
  ✓ Syntax validation: PASSED (1 files)
  ✓ Semantic validation: PASSED
────────────────────────────────────────────────────────────────────────────────
```

Open `model.yaml` to see the rendered result: each device now carries the
banner and hostname with `${SITE}` and `${HOSTNAME}` already replaced by
their values.

As on the Meraki side, the schema and semantic rules come with the module.
To see exactly what gets loaded from where, add `--list-artifacts` - `nac
validate` passes it through to `nac-validate`:

```sh
nac validate --list-artifacts
```

```text
$ /usr/local/bin/terraform apply -target=module.iosxe.local_sensitive_file.model -auto-approve

────────────────────────────────────────────────────────────────────────────────
Render Summary
────────────────────────────────────────────────────────────────────────────────
  ✓ Render: OK (module.iosxe.local_sensitive_file.model -> model.yaml)
────────────────────────────────────────────────────────────────────────────────

$ /home/demouser/.local/bin/nac-validate model.yaml --list-artifacts

Artifact Layers (highest priority first):
  module 'iosxe' 1.1.0-beta.1 at /mnt/c/Users/demouser/Desktop/network-as-code/ios-xe/.terraform/modules/iosxe [module]

Effective Schema:
  /mnt/c/Users/demouser/Desktop/network-as-code/ios-xe/.terraform/modules/iosxe/nac/schema.yaml [module]

Available Validation Rules:
────────────────────────────────────────────────────────────────────────────────

  [313] Verify route-map match prefix-lists reference defined prefix-lists (HIGH) [module]

────────────────────────────────────────────────────────────────────────────────
Total: 1 rules
```

Everything here comes from the `module` layer - the module version pinned
in `main.tf`. If you added your own `.schema.yaml` or `.rules/` folder in
`ios-xe/`, it would show up as an additional, higher-priority `local`
layer.

### Try it: a semantic failure

Rule `313` checks exactly what `Border` configures: every prefix list a
route map matches on must be defined. Change the reference in
`data/2_border.nac.yaml` from `PL_LAB_MGMT` to `PL_LAB_MGTM` and run
`nac validate` again:

!!! failure "Semantic validation: FAILED"
    ```text
    $ /usr/local/bin/terraform apply -target=module.iosxe.local_sensitive_file.model -auto-approve

    ────────────────────────────────────────────────────────────────────────────────
    Render Summary
    ────────────────────────────────────────────────────────────────────────────────
      ✓ Render: OK (module.iosxe.local_sensitive_file.model -> model.yaml)
    ────────────────────────────────────────────────────────────────────────────────

    $ /home/demouser/.local/bin/nac-validate model.yaml

    [RULE 313] Verify route-map match prefix-lists reference defined prefix-lists

    ================================================================================
    ROUTE-MAP REFERENCES UNDEFINED PREFIX-LIST
    ================================================================================

    Found 1 violation(s).

    Route-map entries referencing undefined prefix-lists:
      • ipv4_address_prefix_lists references undefined prefix-list 'PL_LAB_MGTM'
        Path: iosxe.devices[name=Border].configuration.route_maps[name=RM_LAB_MGMT].entries[seq=10].match.ipv4_address_prefix_lists

    --------------------------------------------------------------------------------
    WHY THIS MATTERS:
    --------------------------------------------------------------------------------

    "match ip address prefix-list" and "match ipv6 address prefix-list" in a
    route-map must reference an existing IPv4 or IPv6 prefix-list. IOS-XE
    accepts a reference to an undefined prefix-list, but the entry then
    matches differently than intended, which silently changes routing
    policy.

    ────────────────────────────────────────────────────────────────────────────────
    RECOMMENDED FIX:
    ────────────────────────────────────────────────────────────────────────────────

    Define the prefix-list (prefix_lists for IPv4, ipv6_prefix_lists for
    IPv6) or fix the route-map reference:

      iosxe:
        devices:
          - name: Router1
            configuration:
              prefix_lists:
                - name: PL_DEFAULT
                  seqs:
                    - seq: 10
                      action: permit
                      prefix: 0.0.0.0/0
              route_maps:
                - name: RM_IN
                  entries:
                    - seq: 10
                      operation: permit
                      match:
                        ipv4_address_prefix_lists:
                          - PL_DEFAULT

    ================================================================================

    ────────────────────────────────────────────────────────────────────────────────
    Validation Summary
    ────────────────────────────────────────────────────────────────────────────────
      ✓ Syntax validation: PASSED (1 files)
      ✗ Semantic validation: FAILED (1 violation)

        • 1 HIGH severity violation (rules: 313)
    ────────────────────────────────────────────────────────────────────────────────
    ```

The device itself would accept this - only the rule catches it. Set the
reference back to `PL_LAB_MGMT` and re-run `nac validate` before you deploy.

## Plan and Apply

```sh
nac plan
```

`plan` is essentially a dry run: it shows what Terraform *would* change to
match your YAML, without changing anything on the devices. On this first run
there's nothing in Terraform's state yet, so it doesn't even contact the
devices - everything simply shows up as new. From the next run on, `plan`
first re-reads every resource it manages from the devices over NETCONF and
then shows only the differences. It ends with:

```text
Plan: 10 to add, 0 to change, 0 to destroy.
```

That's a login banner (`iosxe_banner`) and a hostname (`iosxe_system`) for
each of the four devices, plus the prefix list and the route map on
`Border`.

```sh
nac apply
```

!!! warning "No confirmation prompt"
    As in the Meraki part, `nac apply` applies the saved `plan.tfplan`
    directly - check the plan before running it.

Each change is written to the device's candidate datastore and committed
on its own, one resource at a time - never straight to the running
configuration, as described in
[step 1](IOSXE01_ssh.md#this-lab-uses-netconf).

!!! tip "Verify on the devices"
    Connect to any device with Solar-PuTTY: the new login banner greets you
    with the site and device name filled in. You can also check it with:

    ```text
    show banner login
    ```

    The hostname doesn't visibly change - the baseline configuration
    already set it to the device name. What's new is that Network as Code
    now manages it: from here on, the YAML is the source of truth for it.

    On `Border` only, check the device-specific configuration:

    ```text
    show ip prefix-list PL_LAB_MGMT
    show route-map RM_LAB_MGMT
    ```

    On the other three devices, neither exists.

## Testing it: run `nac test`

```sh
nac test
```

```text
$ /usr/local/bin/terraform apply -target=module.iosxe.local_sensitive_file.model -auto-approve

────────────────────────────────────────────────────────────────────────────────
Render Summary
────────────────────────────────────────────────────────────────────────────────
  ✓ Render: OK (module.iosxe.local_sensitive_file.model -> model.yaml)
────────────────────────────────────────────────────────────────────────────────

$ /home/demouser/.local/bin/nac-test -d model.yaml -o tests/results


📄 Merging data model files...
✅ Data model merging completed (< 1s)

🤖 Running Robot Framework tests...

📝 Rendering Robot Framework templates...
🤖 Executing Robot Framework tests...


Initialized logging in /mnt/c/Users/demouser/Desktop/network-as-code/ios-xe/tests/results/robot_results/pabot_results
Robot Framework remote server at 127.0.0.1:49457 started.
Storing .pabotsuitenames file
2026-11-16 15:41:39.843671 [PID:7136] [0] [ID:0] EXECUTING Robot Results.Config.Prefix Lists
2026-11-16 15:41:44.857158 [PID:7136] [0] [ID:0] still running Robot Results.Config.Prefix Lists after 5.0s
2026-11-16 15:41:52.377016 [PID:7136] [0] [ID:0] PASSED Robot Results.Config.Prefix Lists in 12.5 seconds
2 tests, 2 passed, 0 failed, 0 skipped.
===================================================
Output:  /mnt/c/Users/demouser/Desktop/network-as-code/ios-xe/tests/results/robot_results/output.xml
XUnit:   
/mnt/c/Users/demouser/Desktop/network-as-code/ios-xe/tests/results/robot_results/xunit.xml

Log:     
/mnt/c/Users/demouser/Desktop/network-as-code/ios-xe/tests/results/robot_results/log.html

Report:  
/mnt/c/Users/demouser/Desktop/network-as-code/ios-xe/tests/results/robot_results/report.html

Finalizing Pabot execution...
Stopping PabotLib process
Robot Framework remote server at 127.0.0.1:49457 stopped.
PabotLib process stopped
Total testing: 12.50 seconds
Elapsed time:  14.15 seconds
Logs flushed successfully.


======================================================================
Combined Test Execution Summary
----------------------------------------------------------------------
2 tests, 2 passed, 0 failed, 0 skipped.
----------------------------------------------------------------------
Dashboard:  /mnt/c/Users/demouser/Desktop/network-as-code/ios-xe/tests/results/combined_summary.html
Robot:      /mnt/c/Users/demouser/Desktop/network-as-code/ios-xe/tests/results/robot_results/log.html
xUnit:      /mnt/c/Users/demouser/Desktop/network-as-code/ios-xe/tests/results/xunit.xml
======================================================================


Total runtime: 14.62s

✅ All tests passed: 2 out of 2 tests
```

The module's bundled tests check every prefix list in the model against the
device's running configuration, so this run verifies `PL_LAB_MGMT` on
`Border`. Open `tests/results/combined_summary.html` in the integrated
browser, as in the Meraki part, to see the result.

---

**← Previous:** [SSH to devices](IOSXE01_ssh.md) · **Next:** [Device groups](IOSXE03_device_groups.md)
