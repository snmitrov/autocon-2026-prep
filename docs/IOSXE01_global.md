# Part 2 - IOS-XE

Project folder: `ios-xe/`. Module:
[`netascode/nac-iosxe`](https://registry.terraform.io/modules/netascode/nac-iosxe/iosxe/latest).
Prerequisites (provider credentials, devices table) are in `ios-xe/README.md` - this guide focuses on what each step teaches. The underlying concepts
(global → device group → device precedence, variables, `model` templates)
follow the upstream
[`nac-iosxe-learning-lab`](https://netascode.github.io/nac-iosxe-learning-lab/)
Tasks 03/04/06/07 almost verbatim, adapted to this lab's actual 4-device
topology.

The topology is intentionally simple: `Border`, `Core`, `Access1`, and
`Access2` - four IOS-XE devices, plus two Alpine Linux hosts (`Host1`,
`Host2`) attached to `Access1`/`Access2` for end-to-end connectivity testing.
Every device shares a single management subnet, `198.18.128.0/18`, on VLAN1.
No interface or uplink wiring is modeled in the YAML - only device identity
(`name`/`host`/`HOSTNAME`) and, from step 4 onward, shared config applied via
device groups and templates. See `ios-xe/README.md` for the full addressing
table.

## Step 2 - `data/1_global.nac.yaml`: global configuration and variables

Global configuration applies to **every** registered device unless overridden
at the device-group or device level - the precedence hierarchy is device >
device group > global. This file defines two things:

- A **global variable**, `${SITE}`, set once and inherited by all 4 devices.
- A login banner and `system.hostname` that both reference `${HOSTNAME}` - a
  variable that doesn't exist yet at this level. It's defined **per device**
  in step 3, so the same global template resolves to a different literal
  hostname on each device.

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

**Key idea:** variables let you write one banner template instead of four -
one place to define the hostname per device, used in multiple configuration
sections (banner text *and* the `hostname` CLI command).

---

**← Previous:** [SSH to devices](IOSXE00_ssh.md) · **Next:** [Devices](IOSXE02_devices.md)
