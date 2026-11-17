# Glossary

Acronyms and terms used throughout this lab guide. Bookmark or keep this tab
open - new terms appear across almost every step.

| Term | What it means |
|---|---|
| NaC | Network as Code - Cisco's Terraform-based declarative automation framework. This lab covers two flavors of it: Meraki and IOS XE. |
| IaC | Infrastructure as Code - the broader category of "manage infrastructure by editing files, not clicking buttons." Network as Code is IaC for networking. |
| YAML | A human-readable data format (indentation-based). All your Network as Code "intent" files are YAML. |
| YANG | A standardized modeling language for network device configuration and state. IOS XE's configuration surface is described in YANG modules; the IOS XE track of Network as Code ultimately produces YANG data to push to devices. Not used by the Meraki track. |
| NETCONF | A standards-based network management protocol (RFC 6241). Runs over SSH on TCP/830. Uses YANG models and a candidate/running datastore pair - the IOS XE track uses it for all configuration push. The Meraki track uses the Dashboard's REST API instead. |
| Terraform | HashiCorp's declarative infrastructure engine. Reads `.tf` files + state, produces a plan, applies it. This lab uses Terraform as the orchestrator under Network as Code, for both tracks. |
| HCL | HashiCorp Configuration Language - the syntax `.tf` files are written in (braces, key = value). You'll write very little of this directly; the Network as Code modules abstract it. |
| CML | Cisco Modeling Labs - the virtualized network simulation platform that hosts the lab's IOS XE devices. |
| ACL | Access Control List - used in the IOS XE device-group step. |
| CI/CD | Continuous Integration / Continuous Deployment - the automation that runs your code/config through build/test/deploy stages on every change. This lab uses GitLab CI. |
| GitOps | The practice of using Git as the source of truth for infrastructure state, with CI/CD as the delivery mechanism. Meraki step 7 demonstrates it. |
| MR / PR | Merge Request (GitLab) / Pull Request (GitHub) - the code-review workflow for proposing a change to a branch. In this lab, an MR pipeline only validates and plans; merging into `main` deploys. |
| WSL | Windows Subsystem for Linux - the Linux environment running inside the lab's Windows jump machine, where you run `nac` and `git`. |
| Declarative vs imperative | Declarative: describe what you want (e.g. "VLAN 10 exists with name DATA"). Imperative: describe the steps (`vlan 10`, `name DATA`). Network as Code is declarative - you describe state, the module figures out the steps. |
| candidate / running | NETCONF's two main datastores (IOS XE track only). Changes go to candidate, and a commit applies them to running (live config). |
| BYOA | Bring Your Own Account - the model used for Meraki Dashboard access in this lab: you use your own Dashboard account and API key, shared one organization per two participants. See [Meraki Dashboard (BYOA)](Intro02_environment.md#3-meraki-dashboard-byoa). |
| dCloud | Cisco's demo / lab cloud environment - where this lab is hosted. |
| `nac` CLI | The command-line tool you use throughout the lab. It wraps Terraform, `nac-validate`, and `nac-test` into one loop: `nac validate`, `nac plan`, `nac apply`, `nac test`. |
| Module | Reusable Terraform code that maps the Network as Code YAML to provider resources - here `netascode/nac-meraki/meraki` and `netascode/nac-iosxe/iosxe` from the Terraform Registry. It also ships the schema, semantic rules, and tests. |
| Provider | The Terraform plugin that talks to a platform's API - `CiscoDevNet/meraki` (Dashboard API) and `CiscoDevNet/iosxe` (NETCONF in this lab). |
| Data model / `model.yaml` | All YAML files under `data/`, deep-merged into one model and rendered to `model.yaml`. `nac validate`, `nac plan`, and `nac test` all work from it. |
| Syntax / semantic validation | The two layers of `nac validate`. Syntax validation checks the YAML against the module's schema (types, ranges, required fields). Semantic validation runs rules (Python) for things a schema can't express, like references between objects, compliance, or naming conventions. |
| Plan / apply | `nac plan` is a dry run that shows what would change (`+` create, `~` update, `-` destroy). `nac apply` makes exactly those changes. |
| State | Terraform's record of the objects it manages, used to compare your YAML against reality. Stored in `terraform.tfstate` locally, and in GitLab once the pipeline takes over. |
| Backend | Where Terraform keeps its state - a local file by default, or remote storage such as GitLab's `http` backend (Meraki step 7). |
| Drift | A managed setting changed outside Network as Code, for example by hand in the Dashboard. The next `nac plan` shows it as a `~` update that puts the YAML value back. |
| Template (Network as Code) | A named, reusable block of YAML that networks, devices, or device groups pull in by reference (`templates:`), merged before deployment. Not the same as Meraki Dashboard configuration templates. |
| Device group | IOS XE: configuration applied to several devices at once, by role, location, or service, instead of repeating it per device. |
| Pipeline / job / artifact | A pipeline is a set of jobs that GitLab runs automatically on every push, defined in `.gitlab-ci.yml`. Each job runs commands in a fresh container and can keep files it produced as artifacts, such as `plan.txt`. |
| Default branch | The branch GitLab treats as the main line - `main` in this lab, and the only branch the pipeline deploys from. |
| CI/CD variable | A value stored in the GitLab project settings and passed to every pipeline job, such as `MERAKI_API_KEY`. *Masked* hides it in job logs; *protected* limits it to protected branches. |
| MX / MS / CW | Meraki's product lines used in this lab: MX security appliance, MS switch, and CW wireless access point. |

---

**← Previous:** [Topologies](Topologies.md) · **Next:** [References](References.md)
