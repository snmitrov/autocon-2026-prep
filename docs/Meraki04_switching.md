# Step 4 - Configure Switching

## Move this step's file into place

As in the previous steps, this step's configuration waits in
`data-lab-task/` until you move it into `data/` - that's what adds the
switch device and its settings to the merged model. From `meraki/`:

```sh
mv data-lab-task/4_switching.nac.yaml data/
```

## Open and review the file

Open `data/4_switching.nac.yaml` in VS Code. It adds the switch device per
branch with per-port-range overrides: an uplink trunk port, infra ports
disabled by default, an AP trunk port, and end-user access ports carrying
VLAN 10 data with VLAN 20 as the voice VLAN. Also sets switch-wide settings
(management VLAN 999, MTU, QoS trust rules per VLAN, storm control) and the
wired 802.1X access policy.

**Key idea:** this step depends conceptually on step 3's VLANs (it references
VLAN IDs 10/20/30/40/50/999 defined there), but there is no explicit
dependency in the YAML - Terraform's resource graph handles that at apply
time, regardless of which file either block lives in.

## Validate

Same loop as before, starting with validation:

```sh
nac validate
```

Both syntax and semantic validation should pass. This is what would catch
an invalid port `type`, a VLAN ID out of range, or a malformed
per-port-range override before `nac plan` ever runs.

## Plan and Apply

```sh
nac plan
nac apply
```

Check the plan before applying. It should end with:

```text
Plan: 14 to add, 1 to change, 0 to destroy.
```

The 14 adds are the new switch, its ports, and its settings. The one
change is expected too: `meraki_network_device_claim` is updated in place
(`~`) to add the switch's serial to the devices already claimed in your
network, next to the MX from step 3.

!!! tip "Verify in the Dashboard"
    With your branch network selected, look at:

    - **Switching > Monitor > Switches**: the switch with your
      `branch_ms_serial`.
    - **Switching > Monitor > Switch Ports**: ports 1-2 (uplink) and 9-12
      (AP) as trunks, 3-8 reserved for infrastructure, and 13-24 as access
      ports on VLAN 10 with voice VLAN 20.
    - **Switching > Configure > Switch Settings**: management VLAN 999, the
      QoS rules, MTU 9176, and storm control.
    - **Switching > Configure > Access Policies**: `Wired Access Policy`.

## Testing it: run `nac test`

```sh
nac test
```

The module's bundled tests currently cover the network itself, so you'll
see the same passing tests as in step 3 - a quick check that adding the
switch didn't break anything already deployed.

## Reading a `nac plan`

Every `nac plan` line starts with a symbol that tells you what kind of
change you're looking at:

- `+` create - a new resource that doesn't exist yet.
- `-` destroy - a resource being removed entirely.
- `~` update in place - an existing resource's attribute changes without
  destroying and recreating it.
- `-/+` destroy and re-create - the attribute can't be changed in place, so
  Terraform deletes the resource and creates a new one to apply it.

The MTU change below is a textbook `~`: `default_mtu_size` can be updated on
the live switch without touching anything else about it. That's exactly
what makes it a safe field to practice on - contrast that with a `-/+`
change, which would mean real downtime for whatever gets replaced.

## Try it: change a non-impacting setting

`switch.mtu.default_mtu_size` is currently `9176` (jumbo frames). It's a good
field to practice with - changing it doesn't break reachability to the
switch or any other device, so `nac plan` shows exactly one changed
attribute, an easy, low-risk way to see the plan/apply loop end to end:

```yaml
switch:
  settings:
    vlan: 999
    use_combined_power: false
    uplink_client_sampling: true
    mac_blocklist: false
  mtu:
    default_mtu_size: 1500   # was 9176
```

Then run the usual loop:

```sh
nac validate
nac plan
nac apply
```

The plan shows a single `~` update to `default_mtu_size`. After the apply,
confirm the new value under **Switching > Configure > Switch Settings >
MTU configuration** in the Dashboard. Then set it back to `9176` and run
the same three commands again.

---

**← Previous:** [Networks and the MX appliance](Meraki03_networks.md) · **Next:** [Wireless](Meraki05_wireless.md)
