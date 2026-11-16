# Environment Setup

This lab has four moving pieces. Get oriented on all four before diving into
either track:

1. **Windows Jump Machine** - the shared lab desktop with VS Code, WSL, and
   Terraform pre-installed, reachable over WebRDP without a VPN.
2. **CI/CD** - after running through the steps manually, we will be pushing the configuration to the devices through CI/CD as well. As part of the lab environment we installed GitLab CI, but we will also provide equivalent GitHub Actions you can run in your own repository. The GitLab project is reachable from the jump machine's
   browser, or directly if you're on VPN to run the pipeline.
3. **Meraki Dashboard** - the cloud controller for Part 1, accessed with
   your own account under a Bring Your Own Account (BYOA) model.
4. **IOS-XE Virtual Lab** - the four virtualized switches for Part 2,
   reached over SSH either via the jump machine or directly over VPN.

See the [Cheat Sheet](CheatSheet.md) at any point for the exact URLs and
credentials for each of these.

## 1. Windows Jump Machine

This lab runs on a shared Windows jump machine with VS Code, WSL, Terraform,
and Solar-PuTTY already installed - connect to it through WebRDP.

!!! note "WebRDP connection steps coming soon"
    Instructions for connecting to your jump machine over WebRDP will be
    added here shortly.  You can pull up the lab guide in a web browser on the WebRDP session.  (Remember when using copy and paste from a Mac, use the **control** key)

!!! tip "Working from your own computer instead"
    If you'd rather use your own laptop instead of RDP-ing into the jump
    machine, that's fine - use whatever editor and terminal you're
    comfortable with. Just make sure you have, before the lab starts:

    - **Terraform** installed
    - **[uv](https://docs.astral.sh/uv/)** installed - the `nac` CLI is
      installed and run through it
    - An active connection to the **lab VPN** - the GitLab instance and the
      virtualized IOS-XE devices (CML) only live inside the lab network, not
      on the public internet. On VPN, you'll reach GitLab directly (see
      [part 2](#2-cicd) below) and SSH to the IOS-XE devices directly
      too (see [part 4](#4-ios-xe-virtual-lab)), instead of going through the
      jump machine for either.

The next few sections cover the tools already set up for you on the jump
machine - VS Code, its YAML linting extension, and WSL - before you clone the
lab repo in [part 2](#2-cicd).

### VS Code

Visual Studio Code (VS Code) is a free, lightweight, yet powerful source
code editor developed by Microsoft. It runs on Windows, macOS, and Linux and
has become one of the most popular code editors among developers and IT
professionals.

Key features that make VS Code ideal for Network as Code:

- **Syntax highlighting** - colors and formats YAML files for easy
  readability
- **IntelliSense** - provides intelligent code completion and suggestions
- **Integrated terminal** - run commands directly within the editor
- **Extensions** - add functionality like YAML validators and schema
  support
- **Git integration** - built-in version control for tracking changes
- **Multi-file editing** - work with multiple configuration files
  simultaneously
- **File explorer** - easy navigation through project folders and files

**Open your project folder:**

1. Double-click the **Visual Studio Code** icon on the Windows desktop.
2. Click **File → Open Folder**.
3. Select **Desktop → network-as-code** - an empty folder already created
   for you on the jump machine's desktop.
4. Click **OK**.

!!! note "Nothing to see yet"
    This folder is empty until you clone the lab repo into it from a WSL
    terminal, later on this page (see [WSL](#wsl) below, then [Clone the
    starter repository](#clone-the-starter-repository)).

### YAML linting with the Red Hat extension

Since Network as Code configurations are written in YAML, having proper
syntax validation is essential. VS Code supports YAML linting through the
[YAML extension by Red Hat](https://marketplace.visualstudio.com/items?itemName=redhat.vscode-yaml),
which helps catch syntax errors and enforce best practices as you write your
configuration files.

<figure markdown="span">
  ![Red Hat YAML extension in VS Code](assets/rh.png){ width="70%" }<figcaption>The Red Hat
  YAML extension, pre-installed in your lab environment.</figcaption>
</figure>

This extension provides:

- **Real-time syntax validation** - highlights errors as you type
- **Auto-completion** - suggests valid YAML structures
- **Formatting** - automatically formats your YAML files
- **Schema validation** - can validate against predefined schemas

The YAML extension is already pre-installed in your lab - you'll see syntax
highlighting and error detection automatically as you edit YAML files.

!!! note "File extension matters"
    The YAML extension only recognizes files ending with **`.nac.yaml`** as
    Network as Code YAML files. To benefit from its validation and
    auto-completion, make sure every configuration file you create ends in
    `.nac.yaml`.

### WSL

Windows Subsystem for Linux (WSL) lets you run a Linux environment directly
on Windows without a virtual machine. WSL is pre-installed and already
enabled on the jump machine, and you'll use it to run `git` and Terraform
commands - most DevOps tools, including Terraform, are designed for Linux.

**Open a terminal in VS Code on the jump machine**

1. **Click Terminal → New Terminal** (if you don't see terminal click the 3 dots or maximize VS Code).
This opens PowerShell for the project folder you opened earlier.
2. Drop into the Linux environment by running:

```powershell
wsl
```

<figure markdown="span">
  ![Dropping into WSL from a PowerShell terminal already in the project folder](assets/wsl-enable.png){ width="70%" }<figcaption>Running
  `wsl` from PowerShell drops you into an Ubuntu shell, already positioned
  in the same project folder.</figcaption>
</figure>

Your prompt changes to a Linux-style shell - the project folder comes along
with you, automatically mapped to its path under `/mnt/c/...`. You'll run
every `git` and Terraform command in this lab from this WSL shell, not
directly from PowerShell.

!!! tip "Using your own Windows laptop instead?"
    If WSL isn't installed on your own machine yet:

    1. Open PowerShell and run `wsl --install -d Ubuntu`.
    2. Restart your computer when prompted.
    3. Open a terminal in your project folder and run `wsl` as above to
       drop into it.

### Install the `nac` CLI

This lab drives Terraform/OpenTofu, data validation, and post-deployment
testing through a single command line tool: `nac`. It's published on PyPI
as `nac-cli` and installed with `uv` - run this from your WSL shell:

```sh
uv tool install nac-cli
```

!!! warning "Install `nac-cli`, not `nac`"
    The `nac` package on PyPI is a different, unrelated package - don't use
    `pip install nac` or `uvx nac`. Always install `nac-cli`.

<figure markdown="span">
  ![Successful nac-cli install, showing nac --help output](assets/nac-cli.png){ width="70%" }<figcaption>A
  successful `nac-cli` install - `nac --help` lists the full command
  set.</figcaption>
</figure>

Confirm it installed correctly:

```sh
nac --help
```

```text
 Usage: nac [OPTIONS] COMMAND [ARGS]...

 An umbrella CLI wrapping terraform/tofu, nac-validate, and nac-test.

╭─ Options ────────────────────────────────────────────────────────────────────────────────────────╮
│ --config             <path>                               Path to the nac.yaml config file.      │
│                                                           [env var: NAC_CONFIG]                  │
│                                                           [default: nac.yaml]                    │
│ --verbosity  -v      <DEBUG|INFO|WARNING|ERROR|CRITICAL>  Verbosity level.                       │
│                                                           [env var: NAC_VERBOSITY]               │
│                                                           [default: WARNING]                     │
│ --no-color           <bool>                               Disable colored output (also honored   │
│                                                           via the NO_COLOR env var).             │
│ --version            <bool>                               Show the version and exit.             │
│ --help               <bool>                               Show this message and exit.            │
╰──────────────────────────────────────────────────────────────────────────────────────────────────╯
╭─ Commands ───────────────────────────────────────────────────────────────────────────────────────╮
│ setup     Verify prerequisites and report resolved tool versions.                                │
│ init      Initialize the Terraform/OpenTofu working directory.                                   │
│ validate  Render (if configured) then validate the resolved data paths.                          │
│ plan      Produce a saved plan file, optionally with plan.txt/plan.json artifacts.               │
│ apply     Apply a saved plan file if present, otherwise apply interactively.                     │
│ test      Run nac-test against the configured data/templates/filters/output.                     │
│ destroy   Destroy the managed infrastructure (interactive unless --auto-approve).                │
╰──────────────────────────────────────────────────────────────────────────────────────────────────╯
```

You'll use `nac setup`, `nac init`, `nac validate`, `nac plan`, `nac apply`,
and `nac test` throughout both tracks, instead of calling Terraform or the
validation/testing tools directly.

## 2. CI/CD

- **Your GitLab project** - the lab's own GitLab instance, where your CI/CD
  pipeline actually runs. You won't touch this until [CI/CD
  Pipeline](Meraki07_cicd.md), where you'll repoint your already-cloned repo
  at it and push.

Once you get to that step, you'll reach the GitLab instance itself (to
watch pipelines, open merge requests, etc.) either:

- **From the jump machine** - open a browser and go to the GitLab URL in the
  [Cheat Sheet](CheatSheet.md), and log in with the credentials listed
  there.
- **Over VPN, from your own laptop** - reach the same GitLab URL directly,
  with the same credentials, and work with whatever local editor/terminal
  you set up in [part 1](#1-windows-jump-machine).

For now, the next step just gets the starter repo in place: clone it into
the project folder you already have open in VS Code, then confirm Autosave
is on before you start editing.

### Clone the starter repository

You should already have the `network-as-code` desktop folder open in VS Code and a
WSL terminal running inside it, from [part 1](#1-windows-jump-machine). From
that WSL terminal, clone the public starter repo directly into the current
(empty) folder:

```sh
git clone <starter-repo-url> .
```

!!! warning "Don't miss the trailing `.`"
    The `.` at the end tells git to clone into the current folder. Without
    it, git creates a new subfolder named after the repo, and the paths used
    in the rest of this lab won't match.

This is your workspace for both tracks - it now contains a `meraki/` and an
`ios-xe/` folder, each with its own `main.tf`, `data/`, and `data-lab-task/`.

!!! note "Not your GitLab project yet"
    This clones the public starter repo, not your lab GitLab project -
    that's why no VPN or GitLab login is needed for this step. [CI/CD
    Pipeline](Meraki07_cicd.md) walks through repointing this same repo at
    your GitLab project before you push anything.

### Check Autosave is on

Throughout this lab you'll switch frequently between editing YAML in VS Code
and running Terraform in the WSL terminal. Autosave means every edit is
written to disk immediately, so the terminal always sees your latest changes
without you having to remember to save manually.

On the jump machine, Autosave is already enabled - nothing to do. If you're
working from your own laptop, turn it on in VS Code:

1. Click **File** in the VS Code menu bar.
2. Click **Auto Save** so it has a checkmark next to it.

!!! tip "Verify it's on"
    With Auto Save enabled, the dot on a file's editor tab (shown for
    unsaved changes) disappears a moment after you stop typing, instead of
    staying until you press ++cmd+s++ / ++ctrl+s++.

### Project structure

Before touching Terraform or `.env`, take a quick look at what's actually
inside `network-as-code`:

```text
network-as-code/
├── .env.example          # template for your pod's secrets/variables
├── meraki/               # Part 1 - Meraki track
│   ├── main.tf           # the Terraform module block for this track
│   ├── data/             # what Terraform actually reads - starts empty
│   └── data-lab-task/    # staged files you move into data/ one step at a time
└── ios-xe/               # Part 2 - IOS-XE track
    ├── main.tf
    ├── data/
    └── data-lab-task/
```

Both tracks share the same structure: a `main.tf` that drives the NaC
module, a `data/` folder that the module reads, and a `data-lab-task/`
folder containing files you progressively move into `data/` as the lab
advances. You will work within a single track's folder at a time; commands
such as `nac plan` must always be run from within `meraki/` or `ios-xe/`,
never from the repository root.

### Terraform: the `main.tf` file

Each track's folder in the repo you just cloned already has its own
`main.tf` - you won't write one from scratch. It's worth understanding what's
in it before you start running `nac` against it. Here's `meraki/main.tf`:

```hcl title="meraki/main.tf"
module "meraki" {
  source           = "netascode/nac-meraki/meraki"
  version          = "0.13.0-beta.1"
  yaml_directories = ["data"]
}
```

!!! note "Formatting matters"
    Terraform (`.tf`) files use braces `{}` and proper indentation for
    structure. While Terraform is more forgiving than YAML, consistent
    formatting makes your code readable and maintainable - keep that in mind
    if you ever edit this file by hand.

Understanding the configuration:

- **`module "meraki"`** - declares a Terraform module named `meraki`. Modules
  are reusable Terraform configurations that encapsulate infrastructure
  logic.
- **`source`** - tells Terraform where to find the module. This points to
  the Network as Code for Meraki module on the [Terraform
  Registry](https://registry.terraform.io/modules/netascode/nac-meraki/meraki),
  published by Cisco under the `netascode` namespace. The module handles all
  the complexity of translating YAML configurations into the Terraform
  HashiCorp Configuration Language (HCL) code needed by the Meraki Terraform
  provider.
- **`version = "0.13.0-beta.1"`** - pins the module to an exact release
  instead of whatever is newest on the Registry, so every run (yours, your
  teammates', and the CI pipeline's) uses the same module code. This lab uses
  a pre-release (`-beta.1`) version. Terraform only selects a pre-release
  when you name it exactly - a range like `>= 0.13.0` never matches one - so
  for stable releases you could instead write:
    - An exact version, e.g. `version = "0.12.0"`.
    - A range that accepts patch updates, e.g. `version = "~> 0.12.0"`.
- **`yaml_directories = ["data"]`** - specifies which directories contain
  your YAML configuration files. Terraform automatically discovers and
  processes every YAML file within the `data/` folder - more flexible than
  listing individual files, since you can add multiple YAML files to
  `data/` and they'll all be processed automatically.

### Copy `.env.example` to `.env`

```sh
cp .env.example .env
```

Everything in the file already has a working default for the lab except a
handful of pod-specific values - you'll fill those in once you have them:
`MERAKI_API_KEY` after [generating it](Meraki01_login.md#generate-your-meraki-api-key),
and `org_name`/`branch_name`/the device serials once you reach [Org and
global settings](Meraki02_org_global.md#set-your-pods-values-in-env).

!!! note "`.env` stays local - never committed"
    `.env` is gitignored - only the blank `.env.example` template is tracked
    in Git. See the [Cheat Sheet](CheatSheet.md) for `source`-ing it before
    you run Terraform, and for the separate GitLab CI/CD Variables the
    pipeline reads instead.

## 3. Meraki Dashboard (BYOA)

Meraki Dashboard access in this lab follows the Bring Your Own Account
(BYOA) model: you use your own Meraki Dashboard account and your own API
key throughout Part 1 - Cisco does not store or manage your credentials.
Cisco grants your account administrator access to a shared lab
organization, but the account, email, and API key are all yours.

If the email you used for the lab reservation is associated with an existing
Dashboard account, you should have received a notification that new Cisco
Meraki administrator privileges have been granted to your account. Follow
the instructions in the email to accept the invite.

<figure markdown="span">
  ![Meraki Dashboard - create password](assets/image2.png){ width="70%" }<figcaption>Creating
  your Dashboard password on first login.</figcaption>
</figure>

If this is your first time accessing Meraki Dashboard with this email, the
message will guide you to create a password.

<figure markdown="span">
  ![Meraki Dashboard - organization selector](assets/image3.png){ width="70%" }<figcaption>Selecting
  your shared lab organization from the top-left org switcher.</figcaption>
</figure>

!!! danger "Shared organization"
    One Meraki organization is shared by **two participants**. Each of you
    will configure **exactly one** network within that shared org - make
    sure your network name (`branch_name`) is unique so it doesn't collide
    with your pod partner's.

This lab is designed for learning; the configurations shown are not intended
for production use as-is. Production deployments require additional
considerations around state storage, secret management, access control, and
approval workflows - most of which we note in context but do not implement
here.

## 4. IOS-XE Virtual Lab

Part 2 of the lab uses four virtualized IOS-XE switches (`Border`, `Core`,
`Access1`, `Access2`), hosted in Cisco Modeling Labs (CML) inside the lab
network - see [Topologies](Topologies.md) for the full diagram. All four
devices share one set of SSH credentials; the IP addresses and credentials
are listed in the [Cheat Sheet](CheatSheet.md).

- **From the jump machine** - use Solar-PuTTY, pre-installed with every
  device already configured. See [Part 2 - SSH to the lab
  devices](IOSXE01_ssh.md) for the full walkthrough.
- **Over VPN, from your own laptop** - SSH to each device's IP address
  directly, using the credentials in the Cheat Sheet.

---

**← Previous:** [Overview](Intro01_overview.md) · **Next:** [Part 1 - Meraki: access your organization](Meraki01_login.md)
