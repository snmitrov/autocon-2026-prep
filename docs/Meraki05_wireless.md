# Step 5 - Configure Wireless

## Move this step's file into place

As in the previous steps, this step's configuration waits in
`data-lab-task/` until you move it into `data/` - that's what adds the AP
device, RF profile, and SSIDs to the merged model. From `meraki/`:

```sh
mv data-lab-task/5_wireless.nac.yaml data/
```

## Open and review the file

Open `data/5_wireless.nac.yaml` in VS Code. It adds:

- the access point for your branch, claimed by `branch_cw_serial`
- an RF profile, `Corp wireless rf profile`, with dual-band operation and
  band steering for both SSIDs
- two SSIDs:
    - `Data` - 802.1X against the two RADIUS servers, WPA3 Transition Mode,
      VLAN 10, with 802.11r (fast roaming) and 802.11w (management frame
      protection, optional so older clients can still connect)
    - `Guest` - open with a click-through splash page, VLAN 50, isolated
      from the LAN

Both SSIDs are switched off on Saturdays and Sundays from 00:00 to 06:00
for maintenance. This is the last step that writes configuration directly
under the network - step 6 shows how templates let you define it once and
reuse it.

## Validate

```sh
nac validate
```

Both syntax and semantic validation should pass.
Before you plan and apply, notice that Meraki Dashboard does not currently have Wireless on the side menu.  It will appear after deployment.

## Plan and Apply

```sh
nac plan
nac apply
```

Check the plan before applying - it adds the access point, the RF profile,
and the two SSIDs.

!!! tip "Verify in the Dashboard"
    With your branch network selected, look at:

    - **Wireless > Monitor > Access Points**: the access point with your
      `branch_cw_serial`.
    - **Wireless > Configure > SSIDs**: `Data` (802.1X, VLAN 10) and
      `Guest` (open, VLAN 50), next to the default SSID Meraki creates for
      every network.
    - **Wireless > Configure > Access Control**: pick an SSID at the top to
      see its authentication and VLAN settings.
    - **Wireless > Configure > Splash Page**: the click-through splash page
      for `Guest`.
    - **Wireless > Configure > SSID Availability**: pick `Guest` or `Data`
      to see the weekend maintenance schedule.
    - **Wireless > Configure > Radio Settings**, tab **RF profiles**:
      `Corp wireless rf profile`. It shows as applied to 0 access points -
      this lab defines the profile but doesn't assign it to the AP.

## Try it: detect configuration drift

So far every change started in the YAML. In real life, someone eventually
"just quickly fixes" something directly in the Dashboard - and the
Dashboard no longer matches the YAML. That's **configuration drift**. See
how Network as Code handles it:

1. In the Dashboard, go to **Wireless > Configure > Access Control**, pick
   the `Guest` SSID at the top, set **SSID status** to **Disabled**, and
   click **Save Changes**.
2. Back in the terminal, run:

    ```sh
    nac plan
    ```

    You didn't touch the YAML, yet the plan isn't empty: Terraform re-reads
    the live configuration, notices `Guest` is disabled while the YAML says
    `enabled: true`, and proposes a single `~` update to switch it back on.

3. Apply it:

    ```sh
    nac apply
    ```

    `Guest` is enabled again - the YAML wins. This is why the YAML is the
    single source of truth: a manual change to a managed setting doesn't
    survive the next `nac apply`. If a change is meant to stay, it belongs
    in the YAML.

!!! note "Terraform only watches what it manages"
    Drift detection covers only the settings your YAML actually configures.
    Change something Terraform doesn't manage - for example the default
    SSID Meraki created for your network, or a setting your YAML never
    mentions - and `nac plan` stays empty: Terraform neither notices nor
    reverts it. Anything you want kept in line has to be in the YAML.

    The flip side is that this allows split ownership: Network as Code can
    manage some parts of the configuration while others stay manual or
    belong to other automation. Just make sure each setting has exactly
    one owner - if two tools manage the same setting, each one keeps
    overwriting the other's changes.

## A note on where Terraform keeps track of state

When you run `nac apply` locally, Terraform needs to remember what it
already created so the next `plan` can compare your YAML against reality
instead of rediscovering everything from the Dashboard. That record is the
**state file**. `meraki/main.tf` doesn't configure a backend, so Terraform
falls back to its default: a **local backend**
that writes a `terraform.tfstate` JSON file straight into `meraki/`, next to
`main.tf`.

Open it after an apply and you'll find something like this (trimmed, with
real values replaced):

```json
{
  "version": 4,
  "terraform_version": "1.17.0",
  "serial": 7,
  "lineage": "b2e17f3a-....-redacted",
  "resources": [
    {
      "module": "module.meraki",
      "type": "meraki_network",
      "name": "organizations_networks",
      "provider": "provider[\"registry.terraform.io/ciscodevnet/meraki\"]",
      "instances": [
        {
          "index_key": "US/Org-3665367146726167151/Shawn Branch",
          "attributes": {
            "id": "L_1234567890123",
            "name": "Shawn Branch",
            "product_types": ["appliance", "switch", "wireless"],
            "time_zone": "America/Los_Angeles"
          }
        }
      ]
    }
  ]
}
```

Each entry under `resources` ties one block of your YAML to the real object
Terraform created in the Dashboard - `attributes.id` is the Meraki network ID
assigned the first time it was applied. This is how `plan` knows which real object
belongs to which block of your YAML. On every run, Terraform uses these IDs
to re-read each object's current values from the Dashboard (the
`Refreshing state...` lines in the plan output) and compares them with your
YAML - which is exactly how it caught the drift in the exercise above.

This mapping is also why losing or corrupting `terraform.tfstate` is a real
failure mode, not just an inconvenience: without it, Terraform can't tell
these resources already exist, and the next `plan` may propose recreating
everything from scratch even though nothing actually changed in the
Dashboard.

!!! warning "Local state is a lab convenience, not a production pattern"
    A `terraform.tfstate` file on disk only stays trustworthy when exactly
    one person runs `nac apply` against a given config. In production
    you want state stored and locked somewhere shared, so a second
    engineer's apply can't race yours or silently overwrite your history.
    Terraform supports several remote state backends for this - for
    example S3, HTTP, or Terraform Cloud. You'll switch to remote state
    when you get to the [CI/CD pipeline](Meraki07_cicd.md) in step 7.

---

**← Previous:** [Switching](Meraki04_switching.md) · **Next:** [Templates](Meraki06_templates.md)
