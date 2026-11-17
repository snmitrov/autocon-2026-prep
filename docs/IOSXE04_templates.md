# Step 4 - Configure Templates

## Move this step's files into place

This step has two files, and they move into `data/` together - the template
and the device groups that use it. From `ios-xe/`:

```sh
mv data-lab-task/4_templates.nac.yaml data/
mv data-lab-task/4_vlan_groups.nac.yaml data/
```

## Open and review the files

A device group alone already applies the same configuration to many
devices - that's what step 3 did with the ACL. A template adds something a
group can't: it's **defined once with variables, and rendered with
different values** wherever it's used. This step uses one template to
create two different VLANs, and decides per VLAN which devices get it.

### The template

`4_templates.nac.yaml` defines a single template, `vlan`. It's of
`type: model`, so its content is regular data-model YAML. The VLAN ID and
name are placeholders, not values:

```yaml
---
iosxe:
  templates:
    - name: vlan
      type: model
      configuration:
        vlan:
          vlans:
            - id: ${VLAN_ID}
              name: ${VLAN_NAME}
```

### One device group per VLAN

`4_vlan_groups.nac.yaml` creates one device group per VLAN. Each group
lists the devices that get that VLAN, references the `vlan` template, and
sets the template's variables:

```yaml
---
iosxe:
  device_groups:
    - name: VLAN_DATA
      devices:
        - Access1
        - Access2
      templates:
        - vlan
      variables:
        VLAN_ID: 10
        VLAN_NAME: DATA
    - name: VLAN_MGMT
      devices:
        - Border
        - Core
        - Access1
        - Access2
      templates:
        - vlan
      variables:
        VLAN_ID: 99
        VLAN_NAME: MGMT
```

The template is rendered once per group, with that group's variables. A
device in several groups collects all of their VLANs: `Access1` and
`Access2` get DATA and MGMT, while `Border` and `Core` get only
MGMT. To roll out a new VLAN, you add one more group - the template stays
untouched.

These groups have a different purpose than `ACCESS_SWITCHES` from step 3:
that one groups devices by **role**, these decide **where a VLAN goes**.
Both kinds of group can exist side by side, and a device can be a member
of several.

## Validate

```sh
nac validate
```

Both syntax and semantic validation should pass. Open `model.yaml` to see
the result: every device now has a `vlan` section with its VLANs, and the
`${VLAN_ID}` and `${VLAN_NAME}` placeholders are replaced by each group's
values.

!!! tip "Variable values keep their type"
    `VLAN_ID: 10` is a number, as the VLAN ID in the data model requires.
    Write it as `VLAN_ID: "10"` and syntax validation fails with `'10' is
    not a int` - the quotes make it a string.

## Plan and Apply

```sh
nac plan
nac apply
```

The plan adds the VLANs - two each on `Access1` and `Access2`, one each on
`Border` and `Core`:

```text
Plan: 6 to add, 0 to change, 0 to destroy.
```

Each VLAN on each device is its own `iosxe_vlan` resource, for example
`iosxe_vlan.vlan["Access1/10"]` and `iosxe_vlan.vlan["Border/99"]`.

!!! tip "Verify on the devices"
    Connect to `Access1` or `Access2` with Solar-PuTTY and run:

    ```text
    show vlan brief
    ```

    You should see VLANs 10 (`DATA`) and 99 (`MGMT`). Run
    the same command on `Border` or `Core`: there, only VLAN 99 (`MGMT`)
    is added next to the defaults.

---

**← Previous:** [Device groups](IOSXE03_device_groups.md) · **Next:** [Reference: Cheat Sheet](CheatSheet.md)
