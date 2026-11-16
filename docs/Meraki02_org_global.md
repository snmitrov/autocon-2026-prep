# Step 2 - Configure Organization Global Settings

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

## Move this step's file into place

The module only reads `data/` (`yaml_directories = ["data"]` in `main.tf`),
and `data/` starts empty. Every step's file waits in `data-lab-task/` until
it's that step's turn, and moving it into `data/` is what adds it to the
merged model. From the repository root, move this step's file:

```sh
mv meraki/data-lab-task/2_org_global.nac.yaml meraki/data/
```

## Open and review the file

On your VSCode open `data/2_org_global.nac.yaml` and review the configuration. Near the top
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

Your proctor also provided you the serial numbers for your pod's devices via email - set
those too, along with a name of your own choosing for your branch network:

```sh
export branch_name="Your Own Branch Name"
export branch_mx_serial=XXX-XXX-XXX
export branch_ms_serial=XXX-XXX-XXX
export branch_cw_serial=XXX-XXX-XXX
```

`branch_name` can be anything unique to you - for example `"Shawn Branch"` -
just pick something specific to you (like your own name), since two branch
networks share this organization. Stick to letters, numbers, spaces,
hyphens, and underscores: the Dashboard rejects network names with
characters like an apostrophe (`'`).

!!! note "`!env` vs `${...}` - two different variable mechanisms"
    `!env VAR` (used throughout this file) pulls a value from your shell
    environment - `.env` locally, CI/CD variables in the pipeline - and is
    the mechanism for anything secret or pod-specific: API keys, org name,
    device serials, RADIUS secrets. `${VAR}` is a different mechanism you
    may see referenced in the schema docs: a template-scoped variable
    substituted at render time, used to make one template produce different
    output per site (non-sensitive values only). This lab's template step
    (step 6) sticks to static values for simplicity, but `${...}` is what
    you'd reach for if the same template needed to render differently for
    every branch.

Review the rest of the file: it's a deliberately small example that
demonstrates automating organization creation with just a few settings. 

## Source `.env` and Initialize Terraform

With all six variables set, source the file from the repo root so
Terraform's process picks them up, then `cd` into `meraki/` - commands like
`nac setup`/`init`/`plan`/`apply` always run from `meraki/` or `ios-xe/`,
never from the repository root:

```sh
source .env
cd meraki
```

### Check prerequisites with `nac setup`

Before initializing anything, let `nac setup` check that the tools `nac`
drives are installed and report the versions it resolved:

```sh
nac setup
```

```text
────────────────────────────────────────────────────────────────────────────────
Setup Summary
────────────────────────────────────────────────────────────────────────────────
  ✓ uv: found
  ✓ terraform: Terraform v1.17.0 (auto-detected)
  ✓ nac-validate: v2.1.0 (local)
  ✓ nac-test: v2.1.0 (local)
────────────────────────────────────────────────────────────────────────────────
```

Your versions may differ - what matters is a ✓ on every line.

### Initialize the module with `nac init`

With the prerequisites confirmed, initialize the working directory - this
downloads the module and the Meraki provider:

```sh
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
Code site - for example, the schema for `login_security` is documented
at
[netascode.cisco.com/docs/data_models/meraki/organizations/general_management/login_security](https://netascode.cisco.com/docs/data_models/meraki/organizations/general_management/login_security/).

<figure markdown="span">
  ![Network as Code docs - Organization Login Security Configuration](assets/docs.png)<figcaption>The
  `netascode.cisco.com` schema reference for `organizations.login_security`</figcaption>
</figure>

!!! tip "Why `data/` only has one file so far"
    `meraki/data/` - the directory Terraform actually reads - started
    empty, and right now holds only `2_org_global.nac.yaml`, the file you
    moved in at the start of this step. Every later step's file still lives
    in `meraki/data-lab-task/` until it's that step's turn: you move each
    file into `data/` as you reach it, which is what actually adds it to the
    merged model. `data-lab-task/` itself is never read by Terraform - it's
    a staging shelf.

## Validating before you deploy

Network as Code validation happens in two layers that catch different kinds
of mistakes, both running before anything touches the Dashboard:

- **Syntax (schema) validation** checks that your YAML is well-formed and
  that every value matches the schema's expected type, format, and range -
  wrong types, out-of-range numbers, missing required fields. It has no
  opinion on whether a value makes business sense, only whether it's a legal
  value for that field. Under the hood this runs on **Yamale**, a YAML
  schema validator, extended by `nac-validate` with additional
  constraints. The schema itself ships inside the `meraki` Terraform module
  (`nac/schema.yaml`), not as a file in this repo, so it's auto-discovered
  the moment `nac init` has downloaded the module.
- **Semantic (business-rule) validation** goes further: custom logic runs
  against the parsed configuration to enforce rules a schema can't express
  on its own. These can be technology-specific constraints - which features
  or settings are allowed in combination, or whether a reference points at
  something actually defined - but also your organization's own policies,
  such as compliance requirements or naming conventions. The module ships
  one such rule, as an example, auto-discovered the same way. A file can
  pass every syntax check and still fail here.

### Try it: a syntax failure

`login_security.num_different_passwords` in this file is `3` (line 13). The
module's schema declares that field as `int(min=1, max=10, required=False)`
- anything from `1` to `10` is legal. You can see this for yourself once
`nac init` has downloaded the module: open
`meraki/.terraform/modules/meraki/nac/schema.yaml` and search for
`num_different_passwords` - that's the actual file `nac validate` reads
against, not just this doc's description of it. From a terminal **in
`meraki/`**, run `nac validate` with the file as-is first, to see a clean
pass - it auto-discovers the module's schema (and rules) with no extra flags
needed:

```sh
nac validate
```

```text
$ /usr/local/bin/terraform apply -target=module.meraki.local_sensitive_file.model -auto-approve

────────────────────────────────────────────────────────────────────────────────
Render Summary
────────────────────────────────────────────────────────────────────────────────
  ✓ Render: OK (module.meraki.local_sensitive_file.model -> model.yaml)
────────────────────────────────────────────────────────────────────────────────

$ /home/demouser/.local/bin/nac-validate model.yaml

────────────────────────────────────────────────────────────────────────────────
Validation Summary
────────────────────────────────────────────────────────────────────────────────
  ✓ Syntax validation: PASSED (1 files)
  ✓ Semantic validation: PASSED
────────────────────────────────────────────────────────────────────────────────
```

`nac validate` first renders the merged model of everything in `data/` to
`model.yaml` (the same render step `nac plan`/`nac apply` use), then
validates that model against the module's schema and rules. The module's
semantic rule has nothing to check in this file yet - you'll see it catch a
real mistake in [step 3](Meraki03_networks.md#semantic-validation).

Now temporarily lower `num_different_passwords` to `0` (line 13), below the
schema's minimum, and run the exact same command again:

```sh
nac validate
```

!!! failure "Syntax validation: FAILED"
    ```text
      • model.yaml: meraki.domains.[name=US].organizations.[name=...].login_security.num_different_passwords: 0 is less than 1

    ────────────────────────────────────────────────────────────────────────────────
    Validation Summary
    ────────────────────────────────────────────────────────────────────────────────
      ✗ Syntax validation: FAILED (1 error)
    ────────────────────────────────────────────────────────────────────────────────
    ```

A syntax-level violation, caught before anything else runs - semantic
validation doesn't even get a chance to start. Set `num_different_passwords`
back to `3` when you're done, and re-run the command to confirm it passes
again.

## Plan and Apply

With the file passing both validation layers and `num_different_passwords`
back to `3`, deploy it for real. Both commands run from `meraki/`.

### `nac plan`

```sh
nac plan
```

`plan` is essentially a dry run: it reads the current state of your
organization, computes what Terraform *would* change to match your YAML, and
shows you that without changing anything on the Dashboard. The result is
saved to `plan.tfplan`. Run it as often as you like - nothing is deployed
until you run `nac apply`. It ends with a summary line:

```text
    }

Plan: 3 to add, 0 to change, 0 to destroy.

─────────────────────────────────────────────────────────────────────────────

Saved the plan to: plan.tfplan

To perform exactly these actions, run the following command to apply:
    terraform apply "plan.tfplan"
```

`3 to add` is this file's three resources: the org's SNMP settings, its
login security policy, and its VPN firewall rules.
`0 to change, 0 to destroy` confirms nothing in your org already conflicts
with what you're about to create.

Before we apply and push the changes, let's check Meraki Dashboard and see what the Login Security looks like.
**Click Organization > Configure > Click Settings**
<img width="785" height="449" alt="image" src="https://github.com/user-attachments/assets/47fa7ea8-b5e1-48e5-ba85-350f1d163c8d" />
See the current settings:
<img width="800" height="338" alt="image" src="https://github.com/user-attachments/assets/3917a258-28f4-4abb-8d89-56604173960e" />

### `nac apply` Push the changes

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
module.meraki.meraki_organization_snmp.organizations_snmp["US/Dev-SM"]: Creating...
module.meraki.meraki_organization_login_security.organizations_login_security["US/Dev-SM"]: Creating...
module.meraki.meraki_appliance_vpn_firewall_rules.organizations_appliance_vpn_firewall_rules["US/Dev-SM"]: Creating...
module.meraki.meraki_organization_snmp.organizations_snmp["US/Dev-SM"]: Creation complete after 1s [id=709316941310853538]
module.meraki.meraki_organization_login_security.organizations_login_security["US/Dev-SM"]: Creation complete after 1s [id=709316941310853538]
module.meraki.meraki_appliance_vpn_firewall_rules.organizations_appliance_vpn_firewall_rules["US/Dev-SM"]: Creation complete after 2s [id=709316941310853538]

Apply complete! Resources: 3 added, 0 changed, 0 destroyed.
```

!!! tip "Verify in the Dashboard"
    Check that the settings from `data/2_org_global.nac.yaml` actually
    landed. In the [Meraki Dashboard](https://dashboard.meraki.com), make
    sure your lab organization (`Org-[org_id]`) is selected at the top of
    the left-hand menu, then look at:

    - **Login security**:  **Click Organization > Configure > Click Settings**, section
      **Security**: passwords must differ from the last 3, strong passwords
      are enforced, accounts lock after 5 failed attempts, and users are
      logged out after 90 minutes of inactivity.
    - **SNMP** - same page, section **SNMP**: **Version 3** shows *SNMP V3
      enabled*, while Version 2C stays disabled.
    - **VPN firewall rules** - **Security & SD-WAN > Configure >
      Site-to-site VPN**, section **Organization-wide settings**: the
      **Site-to-site outbound firewall** table lists the seven rules
      (Shared Services twice, then Data, IoT, Infra, Voice, and PCI
      Access). This menu belongs to a network, so the `Datacenter` network
      is selected for you - the rules are organization-wide and look the
      same from every network.

    Look, but don't change anything here: the YAML is the single source of
    truth, and a manual edit would be overwritten by the next `nac apply`.

---

**← Previous:** [Access your Meraki organization](Meraki01_login.md) · **Next:** [Networks and the MX appliance](Meraki03_networks.md)
