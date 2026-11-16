# Step 7 - Configure Meraki Networks with a CI/CD Pipeline

Up until now you've driven Terraform manually: `init`, `plan`, `apply`.
That's fine for learning, but production teams run the same workflow through
CI/CD so every change is validated, previewed, applied, and tested the same
way - without a human typing commands. In this task you'll do exactly that,
using the GitLab pipeline already configured in this repo (`.gitlab-ci.yml`
at the repo root).

## What You'll Learn

- How this repo's pipeline maps the steps you've run by hand (`init`,
  `plan`, `apply`) onto `validate`, `plan`, `deploy`, and `test` stages
- Why merge request pipelines only preview a change, while pipelines on
  `main` actually deploy it
- How to push a change, watch the pipeline run, and confirm it actually
  changed something in your Meraki organization

## Pipeline Anatomy

Every push and every merge request triggers a pipeline. Which stages actually
*run* depends on the branch - that's the guardrail against accidental
changes to a live Meraki organization:

| Stage | Runs | What it does |
|---|---|---|
| `validate` | every push/MR | `terraform fmt -check`, then `nac-validate` against the merged model |
| `plan` | MR or `main` | `terraform plan`, saved as `plan.tfplan`/`plan.txt`/`plan.json` job artifacts |
| `deploy` | `main` only | `terraform apply` of the saved plan - the only stage that actually changes your Meraki organization |
| `test` (`idempotency-test` + `config-test`) | `main` only, after `deploy` | re-plans to confirm no drift, and runs the `meraki/tests/templates/` Robot Framework suite against the live Dashboard API |
| `rollback` | `main` only, **on failure** of `deploy` | `terraform destroy`, as a safety net for a partially-applied change |

!!! note "Merge requests only preview"
    Opening a merge request from a feature branch runs `validate` + `plan`
    only - it never touches your Meraki organization. `plan`'s output is
    attached to the pipeline as a downloadable artifact (`plan.txt`), so a
    reviewer can see exactly what would change before anything merges.
    Pushing or merging to `main` is the only thing that triggers `deploy`.

## State

The pipeline stores Terraform state on GitLab itself, via Terraform's `http`
backend - keyed per branch (`TF_STATE_NAME: meraki-${CI_COMMIT_REF_SLUG}`),
so your pod's branch doesn't collide with anyone else's pipeline runs. The
backend credentials (`TF_HTTP_*`) are derived entirely from GitLab's own
predefined CI/CD variables (`CI_JOB_TOKEN`, `CI_PROJECT_ID`, ...) - nothing
to configure by hand.

## Before You Run It: CI/CD Variables

The pipeline needs the same pod-specific values your local `.env` provides -
`MERAKI_API_KEY`, `org_name`, `branch_name`, `branch_mx_serial`,
`branch_ms_serial`, `branch_cw_serial` - set as **GitLab CI/CD Variables**
instead, since the pipeline never reads your local `.env`. See the
[Cheat Sheet](CheatSheet.md) for exactly how to add them and where to find
each value.

## Point Your Repo at GitLab

Up to now, `origin` on your cloned repo still points at the public starter
repo from [Environment Setup](Intro02_environment.md) - that's where you
cloned from, not where the pipeline lives. Before pushing anything,
repoint `origin` at your own GitLab project (the URL from your proctor or
the [Cheat Sheet](CheatSheet.md)):

```sh
git remote set-url origin <your-gitlab-project-url>
git remote -v   # confirm origin now points at GitLab
```

From here on, `git push` goes to your GitLab project, not the starter repo.

## Make a Change

From your WSL terminal, in the repo you already cloned in
[Environment Setup](Intro02_environment.md), create a feature branch:

```sh
git checkout -b cicd-demo
```

Edit one of the files you already deployed by hand earlier in this chapter -
for example, change a tag or a description in `meraki/data/3_networks.nac.yaml`
- then commit and push:

```sh
git add meraki/data/3_networks.nac.yaml
git commit -m "Test CI/CD pipeline"
git push -u origin cicd-demo
```

## Open a Merge Request and Watch It Preview

In GitLab (see the [Cheat Sheet](CheatSheet.md) for the URL and login), open
a merge request from `cicd-demo` into `main`. Go to **Build → Pipelines** and
watch `validate` and `plan` run - `deploy` and `test` stay skipped; they
don't run on an MR pipeline.

Click the `plan` job and open its `plan.txt` artifact to review exactly what
would change before merging.

## Merge and Watch It Deploy

Merge the MR into `main`. This re-triggers the pipeline, now with every stage
active. `deploy` runs `terraform apply` against your real Meraki
organization.

!!! tip "Confirm it actually changed something"
    A green `deploy` job only proves the stage finished without error - not
    that anything changed (a no-op apply against already-matching state is
    also green). Open the `deploy` job log and look for the summary line:

    ```text
    Apply complete! Resources: 1 added, 0 changed, 0 destroyed.
    ```

    All zeros means nothing was pushed - check that your change actually
    made it into `main`, then re-run the pipeline.

After `deploy` succeeds, `idempotency-test` re-plans and fails the pipeline
if it detects drift, and `config-test` runs the Robot Framework suite in
`meraki/tests/templates/` against the live Dashboard API.

## Verify in the Meraki Dashboard (Optional)

Log in to the [Meraki Dashboard](https://dashboard.meraki.com) and confirm
the change you pushed is reflected on your pod's branch network.

## If Deploy Fails

If `deploy` fails, the `rollback` job runs automatically (`main` only,
`when: on_failure`) and runs `terraform destroy` to remove whatever was
partially applied, instead of leaving your organization half-configured.

---

**← Previous:** [Templates](Meraki06_templates.md) · **Next:** [Part 2 - IOS-XE: SSH to devices](IOSXE01_ssh.md)
