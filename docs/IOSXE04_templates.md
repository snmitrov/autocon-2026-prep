# Step 5 - `data/4_templates.nac.yaml` + `data/4_templates_assignment.nac.yaml`: `model` templates

The capstone, mirroring Meraki's step 7. Templates answer *what
configuration* to apply; device groups (step 4) answer *which devices*. Used
together, you get "this exact VLAN set, on exactly these devices" without
duplicating the VLAN definitions per device. Deliberately split into two
files sharing the `4_` prefix - a template with nothing referencing it does
nothing, so they're always read (and deployed) together, and deliberately
*not* called `4_variables.nac.yaml` to avoid confusion with the unrelated
`${VARIABLE}` substitution feature from steps 2-3.

`4_templates.nac.yaml` - the template library, `type: model` (pure YAML
against the data model, schema-validated - as opposed to `file` or `cli`
template types, not used in this lab):

```yaml
---
iosxe:
  templates:
    - name: access_switch_vlans
      type: model
      configuration:
        vlan:
          vlans:
            - id: 10
              name: DATA
            - id: 20
              name: VOICE
            - id: 99
              name: MGMT
```

`4_templates_assignment.nac.yaml` - the reference, merging into the
`ACCESS_SWITCHES` group from step 4 by matching `name: ACCESS_SWITCHES`:

```yaml
---
iosxe:
  device_groups:
    - name: ACCESS_SWITCHES
      templates:
        - access_switch_vlans
```

After `nac apply`, VLANs 10/20/99 land on **Access1 and Access2
only** - not on `Border`/`Core`, which are never added to this template
reference.

**Key idea:** the same deep-merge-by-name mechanic as Meraki's templates
step - NaC reads the template library, finds where it's referenced (here, a
device group instead of a network), and merges the template's configuration
into every member at render time.

## Verifying it on the devices

Once `nac apply` has finished, connect to `Access1` or `Access2` with
Solar-PuTTY and run:

```text
show access-lists | section AccessLayerACL
show vlan brief
show running-config | include ^hostname
```

You should see:

- `AccessLayerACL` with `10 permit 198.18.128.0, wildcard bits 0.0.63.255`,
  from the device group in step 4.
- VLANs 10 (`DATA`), 20 (`VOICE`) and 99 (`MGMT`), from the template above.
- The hostname matching the device name, from the global `${HOSTNAME}`
  variable. Log in again to see the new login banner as well.

Run the same commands on `Border` or `Core`: the hostname and banner are
there, but `AccessLayerACL` is not, and `show vlan brief` lists only VLAN 1
and the default 1002-1005 entries - none of VLANs 10, 20 or 99. That's the
device group and template scoping working as intended.

---

**← Previous:** [Device groups](IOSXE03_device_groups.md) · **Next:** [Topologies](Topologies.md)
