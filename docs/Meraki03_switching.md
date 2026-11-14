# Step 5 - `data/3_switching.nac.yaml`: the MS switch

!!! tip "Move this step's file into place"
    Move `data-lab-task/3_switching.nac.yaml` into `data/` before you run
    `nac plan`/`apply` for this step - that's what adds the switch
    device and its settings to the merged model.

Adds the switch device per branch with per-port-range overrides: an uplink
trunk port, infra ports disabled by default, an AP trunk port, and end-user
access ports carrying VLAN 10 data with VLAN 20 as the voice VLAN. Also sets
switch-wide settings (management VLAN 999, MTU, QoS trust rules per VLAN,
storm control) and the wired 802.1X access policy.

Before any of this reaches the Dashboard, `nac validate` acts like a linter
for the YAML - it's what catches an invalid port `type`, a VLAN ID out of
range, or a malformed per-port-range override before `nac plan` ever runs.

**Key idea:** this step depends conceptually on step 3's VLANs (it references
VLAN IDs 10/20/30/40/50/999 defined there), but there is no explicit
dependency in the YAML - Terraform's resource graph handles that at apply
time, regardless of which file either block lives in.

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

Run `nac plan` to see the single pending change, apply it, confirm it
in **Switch > Switch settings** in the Dashboard, then set it back to `9176`
and repeat - two small, reversible round-trips through the whole pipeline.

---

**← Previous:** [Networks and the MX appliance](Meraki02_networks.md) · **Next:** [Wireless](Meraki04_wireless.md)
