# Step 7 - `data/5_appliance_templates.nac.yaml` + `data/5_appliance_variables.nac.yaml`: templates

!!! tip "Move this step's files into place"
    Move (or copy) both `data-lab-task/5_appliance_templates.nac.yaml` and
    `data-lab-task/5_appliance_variables.nac.yaml` into `data/` together -
    they're a matched pair, and the variables file has nothing to reference
    without the template library already in place.

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
    `templates:` reference. NaC itself has two flavors: `type: model` (what
    this lab uses - a reusable block of configuration) and `type: file`
    (generates a whole config file rather than a block) - this lab only
    exercises the first. Templates can also be parameterized with
    `${variable}` placeholders so the same template renders differently per
    site (see the `!env` vs `${...}` note back in step 3); this lab's
    library sticks to static named blocks for simplicity.

The capstone, and the first point where you stop writing full configuration
per-network and instead write it once, apply it by reference. Deliberately
two files sharing a prefix because they are a matched pair:

- `5_appliance_templates.nac.yaml` is the **template library** - reusable,
  `type: model` appliance firewall-rule templates (`app_fw`, `app_content`,
  `app_intrusion`, `app_mal`), each just a named block of
  `appliance.firewall.*` configuration.
- `5_appliance_variables.nac.yaml` is the **reference** - for each branch
  network, a `templates:` list naming which templates to merge in.

```yaml
# 5_appliance_variables.nac.yaml (excerpt)
networks:
  - name: !env branch_name
    templates:
      - app_fw
      - app_content
      - app_intrusion
      - app_mal
```

The nac module matches `name: !env branch_name` against the network already
defined in step 3 and deep-merges the four templates' configuration into it.
Change a rule in the template once, and it propagates to every network that
references it - the same reusability/consistency/maintainability trade-off
you'll see again in IOS-XE Part 2, step 5.

By the time this merge happens, the two files stop being separate concerns -
`nac`'s render step writes one fully-resolved result to `model.yaml`, the
same rendered model every earlier step's `nac validate`/`nac test` runs
have been reading. Open it after this step and the four templates won't
appear as their own section at all; their `appliance.firewall.*` content is
already inlined under the branch network, indistinguishable from
configuration you'd written directly.

!!! warning "The name must match exactly"
    A `name` that doesn't match is not an error - it's a silent miss. The
    `name` value is compared literally, so a typo'd or hardcoded network name
    simply never pairs up with the network from step 3, and you end up with
    a stray second entry carrying the templates instead of the branch you
    meant to configure. Every data file that targets the branch network
    (`2_networks`, `3_switching`, `4_wireless`, `5_appliance_variables`)
    must use `!env branch_name` so they all resolve to the same value.

**Key takeaway:** templates exist to enforce consistency at scale - one
source of truth for a policy, referenced (not copied) everywhere it applies.

---

**← Previous:** [Wireless](Meraki04_wireless.md) · **Next:** [CI/CD pipeline](Meraki07_cicd.md)
