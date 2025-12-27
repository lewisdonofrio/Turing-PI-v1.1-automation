# =============================================================================
# File: /opt/ansible-k3s-cluster/README.md
# =============================================================================

Turing PI v1.1 - Full Cluster Automation
Distributed Kernel Build - DistCC - Mode-Based Operations - Reproducible Infrastructure

This repository contains the complete automation framework for a Raspberry Pi CM3+
based Turing PI v1.1 cluster. It is engineered for reproducibility, auditability,
multi-user collaboration, and long-term maintainability.

The system implements:

- Cluster-wide distributed kernel compilation using distcc
- Mode-based operation (builder mode vs k3s mode)
- Strict separation of duties
- Self-documenting file headers
- FHS-compliant directory placement
- Multi-user access via the "clusterops" group
- Verification playbooks for long-term diagnostics

This repo is built to be readable, predictable, and future-proof.

===============================================================================
Directory Structure
===============================================================================

Below is the full directory structure in pure ASCII so it renders correctly in
nano, vim, less, and minimal terminals.

    /opt/ansible-k3s-cluster/
    |
    +-- inventory/
    |   |
    |   +-- hosts
    |   |
    |   +-- group_vars/
    |       |
    |       +-- all.yml
    |       +-- build.yml
    |       +-- workers.yml
    |
    +-- roles/
    |   |
    |   +-- builder_user/
    |   |   |
    |   |   +-- tasks/
    |   |       |
    |   |       +-- main.yml
    |   |
    |   +-- distcc_manage/
    |   |   |
    |   |   +-- tasks/
    |   |       |
    |   |       +-- main.yml
    |   |
    |   +-- kernel_build/
    |   |   |
    |   |   +-- tasks/
    |   |   |   |
    |   |   |   +-- main.yml
    |   |   |
    |   |   +-- templates/
    |   |       |
    |   |       +-- makepkg.conf.j2
    |   |
    |   +-- kernel_collect/
    |   |   |
    |   |   +-- tasks/
    |   |       |
    |   |       +-- main.yml
    |   |
    |   +-- kernel_deploy/
    |   |   |
    |   |   +-- tasks/
    |   |       |
    |   |       +-- main.yml
    |   |
    |   +-- kernel_reboot/
    |   |   |
    |   |   +-- tasks/
    |   |       |
    |   |       +-- main.yml
    |   |
    |   +-- kernel_verify/
    |       |
    |       +-- tasks/
    |           |
    |           +-- main.yml
    |
    +-- artifacts/
    |   |
    |   +-- (built kernel packages land here)
    |
    +-- site.yml
    +-- verify_builder.yml
    +-- verify_kernel.yml

===============================================================================
Reasoning Behind the Design
===============================================================================

This automation system is intentionally engineered around clarity, reproducibility,
and operational discipline. Below is the reasoning behind each major design choice.

-------------------------------------------------------------------------------
1. Why /opt/ansible-k3s-cluster?
-------------------------------------------------------------------------------

- /opt is the correct FHS location for add-on cluster software
- Not tied to any user's home directory
- Safe for multi-user access
- Easy to back up, replicate, or mount read-only
- Clean separation from system files

Ownership model:

    owner: builder
    group: clusterops
    permissions: 2775

This ensures:

- builder owns the repo
- all automation-related users (ansible, prometheus, grafana, k3s, future service
  accounts) can collaborate
- new files inherit the correct group

-------------------------------------------------------------------------------
2. Why Mode-Based Operation?
-------------------------------------------------------------------------------

The cluster has two fundamentally different operational states.

-------------------------------------------------------------------------------
Builder Mode
-------------------------------------------------------------------------------

Used only when compiling a new kernel.

- All nodes mount tmpfs
- All nodes run distccd
- All nodes run distcc clients
- PKGBUILD repo synced from kubenode1 to all nodes
- All nodes extract and configure kernel source
- Only kubenode1 performs final packaging
- distcc distributes compile jobs across all nodes
- Kernel package deployed to all nodes
- Nodes reboot serially
- Kernel and modules verified

-------------------------------------------------------------------------------
k3s Mode
-------------------------------------------------------------------------------

Used during normal cluster operation.

- distccd stopped everywhere
- tmpfs unmounted everywhere
- builder user idle
- all RAM returned to workloads

This separation ensures:

- maximum performance during builds
- maximum RAM for k3s during runtime
- no accidental distcc processes consuming resources
- predictable cluster state

-------------------------------------------------------------------------------
3. Why Cluster-Wide Distributed Builds?
-------------------------------------------------------------------------------

Every node participates in the build:

- tmpfs on every node
- distccd on every node
- distcc client on every node
- PKGBUILD synced to every node
- config scripts run on every node
- final packaging only on kubenode1

This provides:

- 28 parallel compile jobs
- consistent build trees
- minimal SD card wear
- maximum RAM performance
- reproducible builds

-------------------------------------------------------------------------------
4. Why Only kubenode1 Does Final Packaging?
-------------------------------------------------------------------------------

Because:

- packaging is I/O heavy
- packaging is single-threaded
- packaging does not benefit from distcc
- packaging must run on a single machine for deterministic output

All nodes still participate in the heavy lifting (compiling .c to .o).

-------------------------------------------------------------------------------
5. Why Self-Documenting File Headers?
-------------------------------------------------------------------------------

Every file begins with:

    # =============================================================================
    # File: /opt/ansible-k3s-cluster/<path>/<filename>
    # =============================================================================

This ensures:

- files are readable even when copied out of context
- future maintainers can instantly locate the file
- the repo is self-navigating
- no ambiguity about where a file belongs

-------------------------------------------------------------------------------
6. Why Verification Playbooks?
-------------------------------------------------------------------------------

These can be run anytime, even months later, even out of order.

verify_builder.yml checks:

- builder user
- distccd state
- tmpfs state

verify_kernel.yml checks:

- kernel package existence
- kernel version on all nodes
- module presence
- module loadability

This provides a diagnostic toolkit for future debugging.

===============================================================================
How to Use This Repo
===============================================================================

Verify builder state:

    ansible-playbook -i inventory/hosts verify_builder.yml

Build and deploy a new kernel:

    ansible-playbook -i inventory/hosts site.yml -t builder_mode

Return to k3s mode:

    ansible-playbook -i inventory/hosts site.yml -t k3s_mode

Verify kernel state:

    ansible-playbook -i inventory/hosts verify_kernel.yml

===============================================================================
Future Extensions
===============================================================================

This repo is designed to grow into a full cluster automation suite:

- k3s installation and upgrades
- Prometheus and Grafana deployment
- Monitoring verification playbooks
- Backup and restore automation
- Node replacement workflows
- Rolling kernel upgrades
- Rolling k3s upgrades

The structure is intentionally modular so new roles can be added without breaking
the core system.

===============================================================================
Summary
===============================================================================

This repository is the operating system for your cluster's automation:

- fully documented
- fully reproducible
- fully mode-aware
- fully distributed
- fully versioned

It is built for future maintainers, including future you.
