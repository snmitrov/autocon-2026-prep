# Step 6 - `data/4_wireless.nac.yaml`: the CW access point and SSIDs

!!! tip "Move this step's file into place"
    Move `data-lab-task/4_wireless.nac.yaml` into `data/` before you run
    `nac plan`/`apply` for this step - that's what adds the AP device,
    RF profile, and SSIDs to the merged model.

Adds the AP device per branch (claimed with tags/location only - deliberately
*not* wired to an RF profile at the device level, to sidestep a known
apply-ordering issue described in `meraki/README.md`), plus network-level
`wireless.rf_profiles` and two SSIDs: `Data` (802.1X/RADIUS, default VLAN 10)
and `Guest` (open, splash page, default VLAN 50).

The `Data` SSID also sets two security fields worth knowing by name:
`dot11r` (802.11r fast BSS transition - lets a client roam between APs
without a full re-authentication handshake, which matters for things like
VoIP over Wi-Fi) and `dot11w` (802.11w management frame protection -
cryptographically signs management frames so they can't be spoofed to force
a deauth). Both are enabled here, but `dot11w` isn't marked `required`, so
clients that don't support it can still connect.

**Key idea:** one more "direct YAML" layer - network + device + SSID
configuration - before the guide pivots to the templating pattern.

## Try it: change a non-impacting setting

Both SSIDs define an `unavailability_schedules` block - `Data` and `Guest`
are both scheduled unavailable Sunday and Saturday 00:00-06:00 for
maintenance. Changing the window only affects when the SSID broadcasts, not
any other device's config, so it's another safe field to practice the
plan/apply loop on:

```yaml
unavailability_schedules:
  enabled: true
  ranges:
    - start_day: Sunday
      start_time: 00:00:00
      end_time: 08:00:00   # was 06:00:00
      end_day: Sunday
    - start_day: Saturday
      start_time: 00:00:00
      end_time: 06:00:00
      end_day: Saturday
```

`nac plan` shows exactly one changed SSID attribute - apply it, confirm
it in **Wireless > SSIDs > Guest > Scheduled availability** in the Dashboard,
then revert.

## What `main.tf` tells Terraform to read

`meraki/main.tf`'s `yaml_directories = ["data"]` is the setting that makes
the `data/` vs `data-lab-task/` staging pattern you've been following
actually work - it's the one line telling the module which folder to
deep-merge every `.nac.yaml` file from. Nothing outside `data/` (including
`data-lab-task/`) is ever read, no matter how correct its content is - that's
the whole mechanism behind "move the file to make it count."

## A note on where Terraform keeps track of state

When you run `nac apply` locally, Terraform needs to remember what it
already created so the next `plan` can compare your YAML against reality
instead of rediscovering everything from the Dashboard. That record is the
**state file**. `meraki/main.tf` leaves its `backend "http" {}` block
commented out, so Terraform falls back to its default: a **local backend**
that writes a `terraform.tfstate` JSON file straight into `meraki/`, next to
`main.tf`.

Open it after an apply and you'll find something like this (trimmed, with
real values replaced):

```json
{
  "version": 4,
  "terraform_version": "1.11.4",
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
          "index_key": "US/Org-3665367146726167151/Shawn's Network",
          "attributes": {
            "id": "L_1234567890123",
            "name": "Shawn's Network",
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
assigned the first time it was applied. This is how `plan` knows the network
already exists and what its current values are, without re-reading the whole
Dashboard on every run.

This caching is also why losing or corrupting `terraform.tfstate` is a real
failure mode, not just an inconvenience: without it, Terraform can't tell
these resources already exist, and the next `plan` may propose recreating
everything from scratch even though nothing actually changed in the
Dashboard.

!!! warning "Local state is a lab convenience, not a production pattern"
    A `terraform.tfstate` file on disk only stays trustworthy when exactly
    one person runs `nac apply` against a given config. In production
    you want state stored and locked somewhere shared, so a second
    engineer's apply can't race yours or silently overwrite your history.
    This repo's own `.gitlab-ci.yml` already shows that pattern: it points
    Terraform at GitLab-managed remote state via the `http` backend
    (`TF_HTTP_ADDRESS` and related variables, one state per branch) - that
    only takes effect once `main.tf`'s `backend "http" {}` block is
    uncommented, which this lab deliberately leaves off so you can run
    everything locally without needing a GitLab token.

---

**← Previous:** [Switching](Meraki03_switching.md) · **Next:** [Templates](Meraki05_templates.md)
