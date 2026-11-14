# Step 4 - `data/3_device_groups.nac.yaml`: device groups

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

**Key idea:** device groups answer *which devices* get a piece of config; the
devices listed under `devices:` must already exist (defined in step 3) for the
group membership to resolve. This naturally depends on step 3, even though
nothing in the YAML enforces that ordering explicitly - Terraform's own
dependency graph (not file order) decides real apply order.

## How this merges into each device

When you run `nac apply`, the module
deep-merges every `data/*.nac.yaml` file - global, device groups, devices -
into one resolved view per device, following the same global → device group
→ device precedence used throughout this lab. Three rules drive that merge:

| Rule | Behavior | Where you've seen it |
|---|---|---|
| Dicts deep-merge by key | Keys from both sides combine; shared keys merge recursively | The global `banner`/`system` block merging with this step's `access_lists` block into one `configuration:` dict per device |
| Lists of scalars append | Strings/numbers/bools are concatenated, in order, duplicates kept | Not exercised in this lab (e.g. a shared `ntp_servers:` list would append this way) |
| Lists of dicts merge by identity key | Entries sharing the same `name` deep-merge into one; otherwise both are kept | `device_groups`/`devices` entries matching on `name:` - mistype a `name` and you silently get two entries instead of one merged one |

For `Access1`, the fully resolved configuration ends up looking roughly like
this - banner/hostname from [global config](IOSXE01_global.md), `access_lists`
from this step:

```yaml
iosxe:
  devices:
    - name: Access1
      host: 198.18.128.204
      configuration:
        banner:
          login: |-
            #########################################
            #   Welcome to the Autocon IOS XE Lab!  #
            #########################################
            Site:   Autocon 2026 IOS XE Lab
            Device: Access1
        system:
          hostname: Access1
        access_lists:
          standard:
            - name: AccessLayerACL
              entries:
                - sequence: 10
                  action: permit
                  prefix: 198.18.128.0
                  prefix_mask: 0.0.63.255
```

`Border` and `Core` get the same global banner/hostname, but no
`access_lists` block - they're never listed under `ACCESS_SWITCHES.devices`.

!!! note "Verifying this"
    [Templates](IOSXE04_templates.md) closes with the `show` commands that
    confirm this ACL lands on `Access1`/`Access2` only - and that `Border`
    and `Core` never receive it.

---

**← Previous:** [Devices](IOSXE02_devices.md) · **Next:** [Templates](IOSXE04_templates.md)
