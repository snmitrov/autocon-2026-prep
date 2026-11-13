# Step 1 - SSH to the Lab Devices

Before diving into Network as Code automation, it's important to establish
baseline connectivity to your IOS-XE devices and understand their current
state. In this task, you'll use Solar-PuTTY to connect to the lab devices
and verify their configuration.

## What You'll Learn

- How to connect to IOS-XE devices using Solar-PuTTY
- How to verify device information with basic `show` commands
- What minimal configuration is required for Network as Code/NETCONF
  automation

## This lab uses NETCONF

Network as Code for IOS XE uses **NETCONF over SSH (TCP 830)** to push
configuration to the devices. See the [Cheat Sheet](CheatSheet.md) for the
shared device credentials used throughout this section.

!!! info "Why NETCONF?"
    NETCONF is transactional. Terraform writes to the device's *candidate*
    datastore, the device validates it, and a `commit` then swaps it into
    the *running* configuration all at once. If anything fails, the proposed
    change is discarded and the running configuration is untouched. RESTCONF
    has no equivalent: it writes straight to running, one HTTP call per
    resource, so a failure part-way through can leave a device partly
    configured. See the [Glossary](Glossary.md) for datastore terms.

## Open Solar-PuTTY

Solar-PuTTY is an enhanced SSH client that provides a tabbed interface for
managing multiple device connections. It's pre-installed on the lab Windows
jump machine and ready to use.

To launch Solar-PuTTY:

1. Look for the **Solar-PuTTY** icon on the Windows desktop.
2. Double-click to open the application.
3. You'll see the Solar-PuTTY interface with a list of devices.

<figure markdown="span">
  ![Solar-PuTTY interface with the lab devices](assets/putty.png){ width="85%" }<figcaption>Solar-PuTTY,
  pre-configured with SSH connections to every lab device.</figcaption>
</figure>

## Connect to the Lab Devices

The lab environment includes four IOS-XE switches. All device credentials
are pre-configured in Solar-PuTTY, so you can connect immediately without
entering any login information.

Devices in this lab:

| Device | Role | IP Address |
|---|---|---|
| Border | Border switch | 198.18.128.201 |
| Core | Core switch | 198.18.128.202 |
| Access1 | Access switch | 198.18.128.204 |
| Access2 | Access switch | 198.18.128.205 |

!!! tip "Additional devices"
    The lab topology also includes `Host1` and `Host2` - two unmanaged
    Alpine Linux hosts attached to `Access1`/`Access2`, used for end-to-end
    connectivity testing. They won't be managed via Network as Code in this
    lab.

!!! note "Lab topologies reference"
    At any time during the lab, refer to [Topologies](Topologies.md) for the
    full topology diagram, device IP addresses, and credentials.

To connect to a device:

1. In Solar-PuTTY, double-click on a device (e.g. `Core`).
2. You'll be automatically logged in with the pre-configured credentials.

## Verify Device Information

Once connected to the switch, run the following command to verify the
device information:

```text
show version
```

This displays:

- IOS XE software version
- Device model
- Uptime and system information
- Hardware details

Take a moment to review the output - you'll see this is a virtual Catalyst
9000 switch running IOS XE.

## Review Current Configuration

Now check the running configuration to see what's currently configured on
the device:

```text
show run
```

!!! note "Minimal by design"
    The lab device configurations are almost empty - this is intentional!
    The switches have minimal configurations, which provides a clean slate
    for you to deploy Network as Code configurations via Terraform. You will
    see a few essential lines that enable Terraform to access the devices.

Once you've reviewed `show version`/`show run` on `Core`, do the same on
`Access1`, `Access2`, and `Border`.

## Configuration Required for Terraform Access

Look for these specific configuration lines in the `show run` output:

```text
username nac_admin privilege 15 secret 9 $9$s7xNTwqH30ICfk$kC0JF...
...
netconf-yang
netconf-yang feature candidate-datastore
```

What these commands do:

- **`netconf-yang`** - enables the NETCONF-over-SSH server on TCP/830. This
  is the channel Terraform uses to push YANG-modelled configuration.
- **`netconf-yang feature candidate-datastore`** - enables the candidate
  datastore. `ios-xe/main.tf` sets `device_transaction = true`, and the
  [data model](https://netascode.cisco.com/docs/data_models/iosxe/entity/device/)
  lists the candidate datastore as a prerequisite for it. Already enabled
  on the lab devices.
- **`username nac_admin privilege 15 ...`** - creates the administrative
  user Terraform uses for authentication. The password is stored hashed, so
  `show run` shows `secret 9 $9$...` rather than the plaintext you'd type
  when configuring it.

!!! tip "Dedicated automation user"
    It's good practice to have a dedicated administrative user configured
    for automation tasks, as shown above with `nac_admin`. This separates
    human and automated access for better security and auditing. With the
    Network as Code framework, this user needs to be configured on every
    device Terraform will manage.

## Enabling NETCONF Manually

!!! note
    You don't need to do this now - the base NETCONF configuration is already
    in place on all lab devices. This is for reference if you ever enable
    NETCONF on a new device.

```text
configure terminal
username nac_admin privilege 15 secret cisco
netconf-yang
netconf-yang feature candidate-datastore
end
write memory
```

`netconf-yang feature candidate-datastore` turns on the candidate / commit /
discard-changes flow that makes applies all-or-nothing. It is a
[documented prerequisite](https://netascode.cisco.com/docs/data_models/iosxe/entity/device/)
for the `device_transaction = true` setting in `ios-xe/main.tf`. Without it,
the provider edits the running configuration directly, one resource at a
time.

!!! warning "NETCONF takes a minute to come up"
    If you try this on your own devices after the event, allow about 60
    seconds after enabling `netconf-yang` before pointing Terraform at the
    device.

    From the device itself, confirm the NETCONF process is up and the
    candidate datastore is present:

    ```text
    show platform software yang-management process
    show netconf-yang datastores
    ```

    `ncsshd` should be `Running`, and the datastore list should show both
    entries:

    ```text
    Datastore Name             : running
    Datastore Name             : candidate
    ```

    If `candidate` is missing, `device_transaction = true` has nothing to
    commit into and the apply will fail.

    From the jump host you can also open the NETCONF subsystem directly - a
    successful connection prints the device's `<hello>` message:

    ```sh
    ssh -s -p 830 <USERNAME>@<IP_ADDRESS> netconf
    ```

    Run that from the WSL/Ubuntu terminal, not from Solar-PuTTY: the `-s`
    subsystem flag needs an OpenSSH client, which the PuTTY family doesn't
    provide.

---

**← Previous:** [CI/CD pipeline](Meraki07_cicd.md) · **Next:** [Global config](IOSXE01_global.md)
