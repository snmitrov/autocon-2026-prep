# Step 6 - Configure Templates

## Move this step's files into place

This step has two files, and they move into `data/` together: they're a
matched pair, and the variables file has nothing to reference without the
template library already in place. From `meraki/`:

```sh
mv data-lab-task/6_appliance_templates.nac.yaml data/
mv data-lab-task/6_appliance_variables.nac.yaml data/
```

## Why templates

Every step so far wrote full configuration directly under one network -
fine for a single branch, but it doesn't scale once the same policy has to
apply to many branches. If ten branch networks each hardcoded the same
firewall rules, changing one rule means editing it in ten places - and
missing one is how configuration drift starts. A template collapses that:
define the rule set once, as a named, reusable block, then have every
network that needs it reference it by name. One edit to the template
propagates everywhere it's referenced, which is what keeps a fleet of
branches consistent as policy evolves - this lab's single network per pod is
enough to show the mechanic, even though the payoff compounds with scale.

!!! note "Not the same as Meraki's own dashboard templates"
    The Dashboard has its own native "configuration templates" feature -
    binding many networks to one cloned config - which is a different
    mechanism entirely. What this step calls a template is a Network as Code
    concept: a named, reusable block of YAML merged into a network via a
    `templates:` reference.

    Native Dashboard templates come with some restrictions - not every
    feature can be configured through them, and a bound network can only
    override certain settings locally.

    NaC templates don't have these limits: they're resolved in the YAML
    before anything is deployed, so they work for anything the data model
    supports, and a network can combine several of them with its own
    directly written configuration.

    NaC itself has two flavors: `type: model` (what this lab uses - a
    reusable block of configuration) and `type: file` (generates a whole
    config file rather than a block). Templates can also be parameterized
    with `${variable}` placeholders so the same template renders
    differently per site; this lab's library sticks to static named blocks
    for simplicity.

## Open and review the files

This is the first step where you stop writing full configuration per
network and instead write it once and apply it by reference. The two files
share a prefix because they're a matched pair:

- `6_appliance_templates.nac.yaml` is the **template library** - four
  reusable `type: model` templates, each a named block of appliance
  configuration:
    - `app_fw` - layer 3 firewall rules and firewalled services
    - `app_content` - content filtering (allowed and blocked URLs and
      categories)
    - `app_intrusion` - intrusion prevention
    - `app_mal` - malware protection
- `6_appliance_variables.nac.yaml` is the **reference** - your branch
  network with a `templates:` list naming which templates to merge in:

```yaml
# 6_appliance_variables.nac.yaml
networks:
  - name: !env branch_name
    templates:
      - app_fw
      - app_content
      - app_intrusion
      - app_mal
```

The module matches `name: !env branch_name` against the network you created
in step 3 - every file names it the same way - and deep-merges the four
templates' configuration into it. Change a rule in the template once, and
it propagates to every network that references it - the same idea you'll
see again in IOS-XE Part 2, step 5.

Because of that deep merge, the `templates:` list doesn't need a file of
its own - you could just as well add it to the network in
`3_networks.nac.yaml`. This lab keeps it in a separate file only so the
whole step can be moved into `data/` in one go.

## Validate

```sh
nac validate
```

Both syntax and semantic validation should pass.

## Plan and Apply

```sh
nac plan
nac apply
```

Check the plan before applying. Notice what it does *not* contain: there's
no resource for the templates themselves. Templates only exist in the YAML -
by the time Terraform sees the model, their content has been merged into
your branch network, so the plan simply adds firewall rules, content
filtering, intrusion prevention, and malware protection to it.

!!! tip "Verify in the Dashboard"
    With your branch network selected, look at:

    - **Security & SD-WAN > Configure > Firewall**: under **Layer 3**, the
      rules from `app_fw` (from `Local Print Access` down to `Allow DIA`
      and `Deny All`), and below them the **WAN appliance services** for
      ICMP ping, web, and SNMP.
    - **Security & SD-WAN > Configure > Content Filtering**: the blocked
      categories under **Category blocking** and the allowed and blocked
      URL patterns under **URL filtering**, from `app_content`.
    - **Security & SD-WAN > Configure > Threat Protection**: Advanced
      Malware Protection enabled (`app_mal`), and intrusion detection and
      prevention in **Prevention** mode with the **Balanced** ruleset
      (`app_intrusion`).

    Nothing in the Dashboard says these came from a template - which is
    exactly the point.

## Try it: see the merged model

`nac validate`, `nac plan`, and `nac test` all work from the same rendered
model, `meraki/model.yaml`. Open it and search for `l3_firewall_rules`: the
rules from `app_fw` sit directly under your branch network's `appliance`
section. The network still lists the template names under `templates:`,
but the template library itself is gone from the model - its content has
been merged in, indistinguishable from configuration you'd written
directly.

## Clean up: run `nac destroy`

In step 7, a GitLab pipeline takes over and keeps its own Terraform state
in GitLab. That state starts empty, so it knows nothing about what you've
deployed by hand. Before you move on, remove everything you deployed in
steps 2-6 - the pipeline will rebuild all of it from the same YAML.

!!! danger "`nac destroy` removes everything you deployed in steps 2-6"
    `nac destroy` doesn't undo just the last step. It removes every resource
    in your local state, `meraki/terraform.tfstate`:

    - **Your branch network is deleted**, with everything configured in it:
      VLANs, group policies, site-to-site VPN, traffic shaping, switch ports
      and settings, SSIDs, the RF profile, and the firewall and security
      settings from the templates.
    - **Your MX, switch, and access point are removed from the network.**
      They stay in the organization's inventory, unassigned, until the
      pipeline claims them again.
    - **Login security and SNMP settings from step 2 stay as they are**:
      Terraform only stops tracking them. Your partner's pod in the same
      organization isn't affected.

    There is no undo in the Dashboard. Your YAML still describes all of it,
    though, so nothing is lost: the pipeline in step 7 deploys it again.

From `meraki/`, run:

```sh
nac destroy
```

Terraform lists every resource it will destroy and ends with the summary
`Plan: 0 to add, 0 to change, 69 to destroy.` - check that the only
network in the list is your own branch network, then type `yes` to
confirm. It finishes with:

```text
Destroy complete! Resources: 69 destroyed.
```

Your branch network no longer shows up in the Dashboard's network list.

---

**← Previous:** [Wireless](Meraki05_wireless.md) · **Next:** [CI/CD pipeline](Meraki07_cicd.md)
