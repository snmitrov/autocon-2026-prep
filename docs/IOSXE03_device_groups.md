# Step 3 - Configure Device Groups

## Move this step's file into place

As in step 2, move this step's file into `data/` - you're already in
`ios-xe/`:

```sh
mv data-lab-task/3_device_groups.nac.yaml data/
```

## Open and review the file

In this step you apply configuration to a *group* of devices at once,
instead of repeating the same YAML per device - a standard ACL is the
concrete example.

Device groups are the right tool whenever configuration follows a role or
scope rather than a single device:

- **Role-based** - access switches vs. core switches vs. border switches.
- **Location-based** - everything in one site or rack.
- **Service rollout** - the same service config across every device running it.
- **Security policy** - a common ACL or hardening baseline across a fleet.

!!! tip "Why groups scale"
    Two switches hardly need a group - but the same file works unchanged if
    `ACCESS_SWITCHES` grows from 2 members to 200: the ACL stays defined in
    exactly one place.

This step introduces one group:

```yaml
---
iosxe:
  device_groups:
    - name: ACCESS_SWITCHES
      devices:
        - Access1
        - Access2
      configuration:
        access_lists:
          standard:
            - name: AccessLayerACL
              entries:
                - sequence: 10
                  action: permit
                  prefix: 198.18.128.0
                  prefix_mask: 0.0.63.255
```

The group gets a standard ACL, `AccessLayerACL`, permitting the lab's
`198.18.128.0/18` management subnet - a stand-in for "the access-layer
devices all need this filter," authored once per role instead of twice. The
ACL is only defined here, not yet applied to an interface.

Device groups answer *which devices* get a piece of config. The devices
listed under `devices:` must exist in the inventory from step 2 for the
group membership to resolve - even though nothing in the YAML enforces that
ordering explicitly, Terraform's own dependency graph (not file order)
decides the real apply order.

### How this merges into each device

The module deep-merges every file in `data/` - global settings, device
groups, inventory - into one resolved configuration per device, following
the device > device group > global precedence. For the exact merge rules,
see
[Merging YAML](https://netascode.cisco.com/docs/guides/concepts/merging_yaml/)
in the Network as Code docs.

## Validate

```sh
nac validate
```

Both syntax and semantic validation should pass.

`nac validate` has also re-rendered `model.yaml`, so you can inspect the
resolved configuration of every device: `Access1` and `Access2` now carry
the ACL next to their banner and hostname, while `Border` and `Core` don't.

## Plan and Apply

```sh
nac plan
nac apply
```

This time `plan` starts with a series of `Refreshing state...` lines: with
step 2 deployed, Terraform first re-reads what it already manages from the
devices. The only new change is the ACL - on `Access1` and `Access2`, and
nowhere else:

```text
Plan: 2 to add, 0 to change, 0 to destroy.
```

One `iosxe_access_list_standard` resource per access switch.

!!! tip "Verify on the devices"
    Connect to `Access1` or `Access2` with Solar-PuTTY and run:

    ```text
    show access-lists AccessLayerACL
    ```

    You should see `10 permit 198.18.128.0, wildcard bits 0.0.63.255`. Run
    the same command on `Border` or `Core`: the ACL doesn't exist there -
    they're not members of `ACCESS_SWITCHES`.

## Testing it: run `nac test`

```sh
nac test
```

The module's bundled tests cover prefix lists, so you'll see the same
passing test as in step 2 - a quick check that adding the device group
didn't break anything already deployed.

## Optional challenge: break it, then fix it

If you have time left, try this one with less guidance. Make `nac test`
fail, then get it passing again - and finish with the YAML exactly as it is
now, so step 4 starts from a clean state.

Hints:

- The bundled tests only check prefix lists. Which device has one?
- There are two ways to make the device and the YAML disagree. Try both.
- What does `nac plan` show after you change the device directly?

??? success "Solution"
    **Change the device.** On `Border`, replace the existing entry of the
    prefix list over SSH. IOS-XE won't overwrite an existing sequence
    number with a different prefix, so remove the full entry first:

    ```text
    configure terminal
    no ip prefix-list PL_LAB_MGMT seq 10 permit 198.18.128.0/18
    ip prefix-list PL_LAB_MGMT seq 10 permit 10.0.0.0/8
    end
    ```

    `nac test` now fails: the device no longer matches the YAML. `nac plan`
    shows the drift as a `~` update, and `nac apply` puts the prefix list
    back - after which `nac test` passes again.

    **Change the YAML.** In `data/2_border.nac.yaml`, change the prefix to
    something else and run `nac test` without applying. It fails, because
    `nac test` renders the changed YAML and compares it with the device,
    which still has the old prefix. Change the prefix back and `nac test`
    passes again.

---

**← Previous:** [Devices and global settings](IOSXE02_devices_global.md) · **Next:** [Templates](IOSXE04_templates.md)
