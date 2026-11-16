# Step 4 - Configure Switching

## Move this step's file into place

As in the previous steps, this step's configuration waits in
`data-lab-task/` until you move it into `data/` - that's what adds the
switch device and its settings to the merged model. From `meraki/`:

```sh
mv data-lab-task/4_switching.nac.yaml data/
```

## Open and review the file

Open `data/4_switching.nac.yaml` in VS Code. It adds:

- the switch for your branch, claimed by `branch_ms_serial`
- its ports, configured per port range:
    - 1-2 - uplink trunk, carrying all the branch VLANs
    - 3-8 - reserved for infrastructure, disabled until needed
    - 9-12 - trunks for the access points, native VLAN 999
    - 13-24 - access ports for end users, data on VLAN 10 and voice on
      VLAN 20, with BPDU guard
- switch-wide settings:
    - management VLAN 999 and jumbo frames (MTU 9176)
    - IGMP snooping for multicast
    - QoS: a DSCP-to-CoS mapping, plus rules that trust the DSCP markings on
      the Data, Voice, IoT, and PCI VLANs and remark Guest traffic to
      best effort
    - storm control limits for broadcast, multicast, and unknown unicast
      traffic
- `Wired Access Policy` - 802.1X against two RADIUS servers, with RADIUS
  accounting and change of authorization (CoA)

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

## Reading a `nac plan`

Every `nac plan` line starts with a symbol that tells you what kind of
change you're looking at:

- `+` create - a new resource that doesn't exist yet.
- `-` destroy - a resource being removed entirely.
- `~` update in place - an existing resource's attribute changes without
  destroying and recreating it.
- `-/+` destroy and re-create - the attribute can't be changed in place, so
  Terraform deletes the resource and creates a new one to apply it.

The MTU change below is a textbook `~`: `default_mtu_size` is updated on
the live switch without replacing anything else about it - unlike a `-/+`
change, which deletes the resource and creates it again.

## Try it: change a setting

`switch.mtu.default_mtu_size` is currently `9176` (jumbo frames). Change it
to `1500` and walk it through the plan/apply loop - `nac plan` should show
exactly one changed attribute:

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
