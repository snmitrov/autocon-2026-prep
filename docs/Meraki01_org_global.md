# Step 3 - Configure Organization Global Settings

Each lab pod shares one Meraki organization between two participants, so two
branch networks live side by side under the same org. The organization
itself is already created for you, along with a shared Datacenter network
that every branch VPNs into - this step doesn't create any of that, it
configures organization-level settings on top of it.

An organization in Cisco Meraki is the highest-level container in the cloud
Dashboard hierarchy - it represents a single company, institution, or
department, and every network you configure belongs to one. The
organization level is where settings apply to *everything* below it,
regardless of network or device. 

## Two Key Principles

Two principles underpin everything from here on:

- **Single source of truth.** The YAML under `data/` is the one place that
  defines what your branch network should look like. Nothing is meant to be
  configured ad hoc in the Dashboard outside of it - a manual change made
  there is configuration drift waiting to be overwritten the next time
  someone runs `nac apply`.
- **Declarative, not imperative.** You declare *what* the organization
  should look like - a login security policy, an SNMPv3 user - not *how* to
  get there. There's no sequence of clicks or API calls to write or order;
  the module and provider work that out, and Terraform's own dependency
  graph decides what happens before what, not file order. That's also why
  it doesn't matter which file in `data/` you create first: every
  `.nac.yaml` file there gets deep-merged into one model before anything is
  validated or applied.

## Open and review the file

On your VSCode open `data/1_org_global.nac.yaml` and review the configuration. Near the top
you'll find the organization block with its environment-driven variables:

```yaml
organizations:
  - name: !env org_name
    managed: false
    login_security:
      enforce_password_expiration: false
      password_expiration_days: 40
      enforce_different_passwords: true
      num_different_passwords: 3
      enforce_strong_passwords: true
      enforce_account_lockout: true
      account_lockout_attempts: 5
      enforce_idle_timeout: true
      idle_timeout_minutes: 90
```

Notice that the organization's `name` uses the `org_name` variable, resolved
by the `!env` tag instead of being hardcoded. You'll set that value first in
your local `.env` file, and later in the GitLab CI/CD variables. 

In the provided file, there are other settings, such as SNMP as well as some firewall VPN rules. Examine the configuration. 

## Set your pod's values in `.env`

Edit the `.env` file you copied from `.env.example` in [Environment
Setup](Intro02_environment.md#copy-envexample-to-env), and set the API key
you just generated:

```sh
export MERAKI_API_KEY=your_api_key_here
```

Then set `org_name` to the Org ID your proctor gave you (also visible in the Meraki
Dashboard, as the `Org-[org_id]` pattern from Step 1):

```sh
export org_name=Org-12345678901234
```

Your proctor also provided you the serial numbers for your pod's devices - set
those too, along with a name of your own choosing for your branch network:

```sh
export branch_name=Your Own Branch Name
export branch_mx_serial=XXX-XXX-XXX
export branch_ms_serial=XXX-XXX-XXX
export branch_cw_serial=XXX-XXX-XXX
```

`branch_name` can be anything unique to you - for example `"Shawn's
Network"` - just pick something specific to you (like your own name), since
two branch networks share this organization.

!!! note "`!env` vs `${...}` - two different variable mechanisms"
    `!env VAR` (used throughout this file) pulls a value from your shell
    environment - `.env` locally, CI/CD variables in the pipeline - and is
    the mechanism for anything secret or pod-specific: API keys, org name,
    device serials, RADIUS secrets. `${VAR}` is a different mechanism you
    may see referenced in the schema docs: a template-scoped variable
    substituted at render time, used to make one template produce different
    output per site (non-sensitive values only). This lab's template step
    (step 7) sticks to static values for simplicity, but `${...}` is what
    you'd reach for if the same template needed to render differently for
    every branch.

Review the rest of the file: it's a deliberately small example that
demonstrates automating organization creation with just a few settings. 

## Source `.env` and Initialize Terraform

With all six variables set, source the file from the repo root so
Terraform's process picks them up, then `cd` into `meraki/` and initialize
the module - commands like `nac init`/`plan`/`apply` always run from
`meraki/` or `ios-xe/`, never from the repository root:

```sh
source .env
cd meraki
nac init
```

```text
Initializing the backend...

Initializing modules...

Initializing provider plugins...

Terraform has been successfully initialized!
```

!!! note "Re-source after editing `.env`"
    Variables are only read into your shell when you `source .env`. If you
    come back and edit `.env` later (a new serial, a different
    `branch_name`), `source .env` again before your next `nac plan` or
    `apply` - otherwise Terraform still sees the old values.

## Finding the documentation

How do you know what configuration options are supported, and what YAML
structure they expect? The full data model is published on the Network as
Code docs site - for example, the schema for `login_security` is documented
at
[netascode.cisco.com/docs/data_models/meraki/organizations/general_management/login_security](https://netascode.cisco.com/docs/data_models/meraki/organizations/general_management/login_security/).

<figure markdown="span">
  ![Network as Code docs - Organization Login Security Configuration](assets/docs.png)<figcaption>The
  `netascode.cisco.com` schema reference for `organizations.login_security` -
  the field you're about to break on purpose below.</figcaption>
</figure>

!!! tip "Why `data/` only has one file so far"
    `meraki/data/` - the directory Terraform actually reads - starts with
    just `1_org_global.nac.yaml` in place. Every later step's file lives in
    `meraki/data-lab-task/` until it's that step's turn: you move (or copy)
    each file into `data/` as you reach it, which is what actually adds it
    to the merged model. `data-lab-task/` itself is never read by
    Terraform - it's a staging shelf, not a second source of truth.

## Validating before you deploy

Network as Code validation happens in two layers that catch different kinds
of mistakes, both running before anything touches the Dashboard:

- **Syntax (schema) validation** checks that your YAML is well-formed and
  that every value matches the schema's expected type, format, and range -
  wrong types, out-of-range numbers, missing required fields. It has no
  opinion on whether a value makes business sense, only whether it's a legal
  value for that field. Under the hood this runs on **Yamale**, a YAML
  schema validator - the schema itself ships inside the `meraki` Terraform
  module (`nac/schema.yaml`), not as a file in this repo, so it's
  auto-discovered the moment `nac init` has downloaded the module.
- **Semantic (business-rule) validation** goes further: custom logic runs
  against the parsed configuration to enforce policies a schema can't
  express on its own. The module ships one such rule, as an example,
  auto-discovered the same way. A file can pass every syntax check and
  still fail here.

### Try it: a syntax failure

`login_security.num_different_passwords` in this file is `3` (line 13). The
module's schema declares that field as `int(min=1, max=10, required=False)`
- anything from `1` to `10` is legal. You can see this for yourself once
`nac init` has downloaded the module: open
`meraki/.terraform/modules/meraki/nac/schema.yaml` and search for
`num_different_passwords` - that's the actual file `nac validate` reads
against, not just this doc's description of it. From a terminal **in
`meraki/`**, run
`nac validate` against the file as-is first, to see a clean pass - it
auto-discovers the module's schema (and rules) with no extra flags needed:

```sh
nac validate data/1_org_global.nac.yaml --verbosity DEBUG
```

```text
$ terraform apply -target=module.meraki.local_sensitive_file.model -auto-approve
✓ Render: OK (module.meraki.local_sensitive_file.model -> model.yaml)

$ nac-validate model.yaml data/1_org_global.nac.yaml --verbosity DEBUG
INFO - Artifact layer [module]: module 'meraki' at .terraform/modules/meraki
INFO - Loading schema from .terraform/modules/meraki/nac/schema.yaml
INFO - Loading module rules from .terraform/modules/meraki/nac/rules
INFO - Validate file: model.yaml
INFO - Validate file: data/1_org_global.nac.yaml
INFO - Verifying rule id 302

────────────────────────────────────────────────────────────────────────────────
Validation Summary
────────────────────────────────────────────────────────────────────────────────
  ✓ Syntax validation: PASSED (2 files)
  ✓ Semantic validation: PASSED
────────────────────────────────────────────────────────────────────────────────
```

`nac validate` renders the merged model to `model.yaml` first (the same
render step `nac plan`/`nac apply` use), then validates both the rendered
model and your own file against the module's schema and rules - that's why
two files show up in the summary instead of one. Rule `302` is the module's
packaged semantic rule - more on it below.

Now temporarily lower `num_different_passwords` to `0` (line 13), below the
schema's minimum, and run the exact same command again:

```sh
nac validate data/1_org_global.nac.yaml --verbosity DEBUG
```

!!! failure "Syntax validation: FAILED"
    ```text
    DEBUG - Syntax error 'model.yaml': meraki.domains.[name=US].organizations.[name=...].login_security.num_different_passwords: 0 is less than 1
    DEBUG - Syntax error 'data/1_org_global.nac.yaml': meraki.domains.[name=US].organizations.[name=...].login_security.num_different_passwords: 0 is less than 1

    ────────────────────────────────────────────────────────────────────────────────
    Validation Summary
    ────────────────────────────────────────────────────────────────────────────────
      ✗ Syntax validation: FAILED (2 errors)
    ────────────────────────────────────────────────────────────────────────────────
    ```

A syntax-level violation, caught before anything else runs - semantic
validation doesn't even get a chance to start. Set `num_different_passwords`
back to `3` when you're done, and re-run the command to confirm it passes
again.

### Semantic validation comes from the module too

Besides the schema, the `meraki` module also ships a semantic rule that
checks every `group_policy_name` reference - on an appliance VLAN, an
identity PSK, or an SSID device-type policy - against the group policies
actually defined on that network. Once `nac init` has downloaded the
module, you can read its actual source at
`meraki/.terraform/modules/meraki/nac/rules/302_group_policy_references.py`.
The DEBUG output above already shows it running (`Verifying rule id 302`):
it found nothing to flag, because this file doesn't define any networks,
group policies, or references yet. You'll see it catch a real mistake once
those exist, in [Networks](Meraki02_networks.md).

Rule `302` ships as a single example of what's possible, not the limit of
it - it's just one policy the module's authors chose to demonstrate.
Nothing stops you from writing your own rules for whatever your
organization actually cares about (a naming convention, an approved VLAN
range, a required tag), the same way this one is written - as a Python
class dropped into a `rules/` directory that `nac validate` auto-discovers.
If you'd rather not write them yourselves, Cisco Services can develop
custom semantic rules (and schemas) for your organization's specific
policies.

## Plan and Apply

With the file passing both validation layers and `num_different_passwords`
back to `3`, deploy it for real. Both commands run from `meraki/`.

### `nac plan`

```sh
nac plan
```

`plan` is read-only - it computes what Terraform *would* do without
touching your organization, and saves the result to `plan.tfplan`. It ends
with a summary line:

```text
    }

Plan: 4 to add, 0 to change, 0 to destroy.

Saved the plan to: plan.tfplan

To perform exactly these actions, run the following command to apply:
    terraform apply "plan.tfplan"
```

`4 to add` is this file's four resources: the merged-model file, the org's
SNMP settings, its login security policy, and its VPN firewall rules.
`0 to change, 0 to destroy` confirms nothing in your org already conflicts
with what you're about to create.

### `nac apply`

```sh
nac apply
```

!!! warning "No confirmation prompt"
    Unlike a plain `terraform apply`, `nac apply` applies the `plan.tfplan`
    saved by the previous step directly - it does **not** stop to ask `yes`
    first. Make sure the plan above is really what you want before running
    this: it's the first command in the lab that actually writes to your
    Meraki organization.

```text
module.meraki.local_sensitive_file.model[0]: Creating...
module.meraki.local_sensitive_file.model[0]: Creation complete after 1s [id=1071a02f3c85d841c898795b7b52ac1b58bc9d79]
module.meraki.meraki_organization_snmp.organizations_snmp["US/Dev-SM"]: Creating...
module.meraki.meraki_organization_login_security.organizations_login_security["US/Dev-SM"]: Creating...
module.meraki.meraki_appliance_vpn_firewall_rules.organizations_appliance_vpn_firewall_rules["US/Dev-SM"]: Creating...
module.meraki.meraki_organization_snmp.organizations_snmp["US/Dev-SM"]: Creation complete after 1s [id=709316941310853538]
module.meraki.meraki_organization_login_security.organizations_login_security["US/Dev-SM"]: Creation complete after 1s [id=709316941310853538]
module.meraki.meraki_appliance_vpn_firewall_rules.organizations_appliance_vpn_firewall_rules["US/Dev-SM"]: Creation complete after 2s [id=709316941310853538]

Apply complete! Resources: 4 added, 0 changed, 0 destroyed.
```

!!! tip "Verify in the Dashboard"
    Log in to the Meraki Dashboard and confirm your organization now shows
    the SNMP, login security, and VPN firewall settings from
    `data/1_org_global.nac.yaml`.

---

**← Previous:** [Log in and identify your lab organization](Meraki00_login.md) · **Next:** [Networks and the MX appliance](Meraki02_networks.md)
