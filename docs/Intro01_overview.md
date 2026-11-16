# AutoCon 6 - Network as Code Lab Guide

## Learning objectives

This step-by-step guide walks you through the AutoCon 6 Network as Code
lab, covering **both** Meraki and IOS-XE. By the end, you will know how to
deploy and manage Meraki and IOS-XE infrastructure with declarative
Network as Code YAML and CI/CD pipelines.

!!! tip "New to these acronyms?"
    See the [Glossary](Glossary.md) in the top navigation. Keep it open in a
    separate tab.

The guide walks through both halves of the lab, in order:

- **Part 1 - Meraki**, starting with logging into your lab Dashboard
  organization, then five steps authoring a single-branch Meraki network
  (one per shared pod, appliance/switch/wireless) directly in YAML, ending
  on a templating/indirection capstone.
- **Part 2 - IOS-XE**, a small four-device lab (`Border`, `Core`, `Access1`,
  `Access2`) where you will push some basic configuration to IOS-XE devices directly. 

Meraki is a controller-managed
platform (you configure a cloud Dashboard, which then pushes to devices),
while IOS XE is configured directly, device by device, over NETCONF. Walking
through both shows that Network as Code isn't tied to one architecture - the
same YAML-in, Terraform-module, provider-out workflow automates a
cloud controller and a direct-to-device platform equally well.

## What is Network as Code?

Network as Code (NaC) is a methodology that applies DevOps principles to
network management through declarative data models. Rather than writing
scripts or clicking through GUIs, network engineers describe their intended
network state in human-readable YAML files. The Network as Code toolchain
handles the how: translating intent into platform-specific configuration,
tracking state, and pushing only what changed.

Network as Code is an umbrella that spans multiple Cisco platforms and
architectures. At its core is a deliberately tool-agnostic data model: the
YAML describes *what* the network should look like, not *how* it gets
provisioned. The provisioning engine is a separate choice - most platforms
use Terraform (a NaC Terraform module plus a platform provider), some use
Ansible, and some support both. Whatever the engine, the methodology is the
same: YAML intent -> automation engine -> device/controller.

The key point is who owns the automation code. Every platform comes with its
own APIs, authentication schemes, protocols, object models, and quirks -
and all of that changes from release to release. With Network as Code,
**Cisco maintains that product- and architecture-specific code for you**: the
data models, Terraform modules, providers, Ansible collections, and validation
and test tooling. You maintain only your intent. That helps on day one - you
can start automating without first building and debugging an integration
layer - and on every day after, because keeping pace with new software
releases, API changes, and new features is the vendor's job, not yours.

The supported platforms include ACI (APIC), Nexus Dashboard Orchestrator
(NDO), Nexus Dashboard VXLAN EVPN, NX-OS, Catalyst Center, Catalyst SD-WAN,
Meraki, ISE, Secure Firewall (FMC), IOS XR, and - the two platforms this lab
covers - **Meraki** and **IOS XE**.

- **Network as Code for Meraki** uses the
  `netascode/terraform-meraki-nac-meraki` module and the
  `CiscoDevNet/meraki` provider to push configuration to the Meraki
  Dashboard's cloud-hosted REST API.
- **Network as Code for IOS XE** uses the
  `netascode/terraform-iosxe-nac-iosxe` module and the `CiscoDevNet/iosxe`
  provider to push YANG-modeled configuration to on-box devices
  (Catalyst 9000, C8000V, ISR, ASR, etc.) over NETCONF.

Both tracks in this lab happen to use Terraform. The same intent-first
workflow applies to every Network as Code platform; what differs is the data
model, the automation engine, and the transport.

## Why this lab matters

Traditional network management relies on manual CLI commands, scripts, and
brittle templates. The typical failure modes - configuration drift, human
error, no change history, and no safe way to preview or test changes - are
well known.

This lab shows how Network as Code addresses each of them using:

- **Declarative configuration** - define the desired state, not the steps
  to reach it
- **Terraform** - industry-standard Infrastructure-as-Code engine
- **Pre-change validation** - not just syntactic checks, but also semantic
  rules (cross-references, uniqueness, best practices, your own custom
  rules) that catch misconfigurations before they ever reach a device or the
  Dashboard
- **Post-deployment testing** - verify what was deployed actually matches
  what you asked for
- **CI/CD pipelines** - automate validation, deployment, and testing
  end-to-end

### Terminology

**Network as Code for Meraki** and **Network as Code for IOS XE** are the
same methodology applied to different platforms. You may also see the older
shorthands "Meraki as Code" and "IOS XE as Code" / "IOSXE-as-Code" - they
mean the same thing. Both parts of this lab use the same underlying mechanic:
a Terraform `nac-*` module reads every YAML file under a project's `data/`
directory, deep-merges them into one model, and applies the result.
Dictionaries merge key by key. Two list entries are merged into one when they
share at least one scalar attribute and every scalar attribute they have in
common carries the same value (in practice often the same `name`); if any
shared value differs, both entries are kept. File names and numeric prefixes are
a **reading order**, not a deployment order - Terraform builds its own
dependency graph from the merged model.

## What the Network as Code stack looks like

Network as Code isn't a single tool, it's a layered stack. You write intent
in YAML, and the stack turns it into platform-specific configuration. Both
tracks in this lab have exactly the same five layers and the same workflow.
What changes is what fills each layer: the YAML follows the same conventions
on both tracks but uses each platform's own data model, and the module,
provider, transport, and target are platform-specific:

<figure markdown="span">
  ![The Network as Code stack](assets/nac-stack-layers.svg)
</figure>

| Layer | What it is | Meraki track | IOS XE track |
|---|---|---|---|
| 1. Intent (what you write) | `*.nac.yaml` - declarative YAML, human-readable, under version control | Meraki data model (`meraki:` root) | IOS XE data model (`iosxe:` root) |
| 2. NaC Terraform module | Merges every YAML in `data/`, resolves variables/templates, renders the data model | `netascode/terraform-meraki-nac-meraki` | `netascode/terraform-iosxe-nac-iosxe` |
| 3. Terraform provider | Turns the merged model into resource-level API calls; knows how to diff and converge | `CiscoDevNet/meraki` | `CiscoDevNet/iosxe` |
| 4. Transport | How the provider talks to the platform | HTTPS / REST to the Meraki Dashboard API | NETCONF over SSH (TCP 830), staging changes in the candidate datastore before committing them |
| 5. Target | Where configuration ends up | Meraki Dashboard-managed cloud configuration | Device's YANG-modeled running configuration |

You are responsible for layer 1; Cisco builds and maintains layers 2 through
4. The value of NaC isn't found in any single layer - it's that you no longer
have to write or maintain layers 2, 3, and 4 yourself. You describe intent,
and the module handles module composition, Terraform resource wiring, and
platform-specific API/YANG path construction. When a platform release changes
an API or adds a feature, the module and provider are updated for you - you
bump a version instead of rewriting your automation.

!!! note "New to YANG?"
    YANG is the data modeling language IOS XE uses to describe its
    configuration. You don't need to read or write YANG in this lab (the
    provider handles it). YANG models change between IOS XE releases, and
    the Meraki Dashboard API evolves too, with new endpoints and attributes
    added over time. The difference is where the version lives: on IOS XE it
    is tied to the software running on each device, while the Meraki
    Dashboard API is a cloud service that evolves centrally. Either way,
    tracking those changes is the job of the vendor-maintained module and
    provider, which is why their versions matter.

## What you'll learn

By completing this lab, you will gain hands-on experience with:

- Writing declarative Meraki and IOS XE configurations in Network as Code
  YAML format
- Deploying configurations using the Network as Code Terraform modules
- Understanding the Network as Code configuration hierarchy (org/network and
  global -> group -> device, depending on platform)
- Using variables and templates for reusable, scalable configurations
- Pre-deployment validation with `nac validate` (syntactic, semantic,
  and compliance checks)
- Post-deployment testing with `nac test` (automated Robot Framework
  tests)
- Automating the full Infrastructure-as-Code lifecycle with CI/CD
  pipelines
- Implementing GitOps workflow safeguards (branch protection, merge
  requests)

---

**Next:** [Environment Setup](Intro02_environment.md){.next-only}
