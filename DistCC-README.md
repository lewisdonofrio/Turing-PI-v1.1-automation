# =============================================================================
# File: /opt/ansible-k3s-cluster/README.md
# =============================================================================
# Turing PI v1.1 - Full Cluster Automation
# Distributed Kernel Build - DistCC - Mode-Based Operations - Reproducible Infrastructure
# =============================================================================

This repository contains the complete automation framework for a Raspberry Pi
CM3+/CM4 based Turing PI v1.1 cluster. It is engineered for reproducibility,
auditability, multi-user collaboration, and long-term maintainability.

The system implements:

- Distributed kernel compilation using distcc
- Mode-based operation (K3S MODE vs DISTCC BUILD MODE)
- Strict builder/worker separation of duties
- Self-documenting file headers
- FHS-compliant directory placement
- Multi-user access via the "clusterops" group
- Verification and smoketest playbooks
- Deterministic, reproducible infrastructure

This repo is built to be readable, predictable, and future-proof.

# =============================================================================
# DIRECTORY STRUCTURE
# =============================================================================

Pure ASCII layout for readability in nano, vim, less, and minimal terminals.

    /opt/ansible-k3s-cluster/
    |
    +-- inventory/
    |   +-- hosts
    |   +-- group_vars/
    |       +-- all.yml
    |       +-- build.yml
    |       +-- workers.yml
    |
    +-- manifest/
    |   +-- distcc-hosts.yml
    |
    +-- playbooks/
    |   |
    |   +-- distccd-bootstrap.yml
    |   +-- builder-distccd-guard.yml
    |   +-- worker-distccd-reset.yml
    |   +-- cluster-distcc-validate.yml
    |   +-- cluster-distcc-smoketest.yml
    |   +-- distcc-mode-switch.yml
    |   +-- cluster-mode-restore.yml
    |   |
    |   +-- k3s-bootstrap.yml
    |   +-- k3s-reset.yml
    |   +-- k3s-validate.yml
    |
    +-- roles/
    |   +-- builder_user/
    |   +-- distcc_manage/
    |   +-- kernel_build/
    |   +-- kernel_collect/
    |   +-- kernel_deploy/
    |   +-- kernel_reboot/
    |   +-- kernel_verify/
    |
    +-- artifacts/
    |   +-- (built kernel packages land here)
    |
    +-- site.yml
    +-- verify_builder.yml
    +-- verify_kernel.yml

# =============================================================================
# DESIGN PRINCIPLES
# =============================================================================

This automation system is intentionally engineered around clarity, reproducibility,
and operational discipline.

# -----------------------------------------------------------------------------
# 1. Why /opt/ansible-k3s-cluster?
# -----------------------------------------------------------------------------

- Correct FHS location for add-on cluster software
- Not tied to any user's home directory
- Safe for multi-user access
- Easy to back up or mount read-only
- Clean separation from system files

Ownership model:

    owner: builder
    group: clusterops
    permissions: 2775

Ensures:

- builder owns the repo
- all automation-related users can collaborate
- new files inherit correct group

# -----------------------------------------------------------------------------
# 2. Why Mode-Based Operation?
# -----------------------------------------------------------------------------

The cluster has two operational states:

# --- DISTCC BUILD MODE -------------------------------------------------------

Used when compiling a new kernel.

- builder mounts tmpfs at /tmp/kernel-build
- builder runs distcc client only
- workers run distccd
- workers provide remote cc1 execution
- override.conf enforced on workers
- symlinks in /usr/lib/distcc enforced
- distributed compile via distcc
- final packaging on builder only

# --- K3S MODE ----------------------------------------------------------------

Used during normal cluster operation.

- k3s-server active on builder
- k3s-agent active on workers
- distccd stopped everywhere
- tmpfs unmounted on builder
- maximum RAM returned to workloads

This separation ensures:

- maximum performance during builds
- maximum RAM for k3s during runtime
- predictable cluster state

# -----------------------------------------------------------------------------
# 3. Why Distributed Builds?
# -----------------------------------------------------------------------------

All workers participate:

- distccd on workers
- distcc client on builder
- consistent gcc toolchain
- override.conf ensures correct distccd behavior
- symlinks ensure correct compiler invocation

Provides:

- parallel compile jobs across all nodes
- minimal SD card wear
- maximum RAM performance
- reproducible builds

# -----------------------------------------------------------------------------
# 4. Why Only Builder Does Final Packaging?
# -----------------------------------------------------------------------------

- packaging is I/O heavy
- packaging is single-threaded
- packaging does not benefit from distcc
- deterministic output requires a single machine

Workers still perform the heavy lifting (cc1 execution).

# -----------------------------------------------------------------------------
# 5. Why Self-Documenting File Headers?
# -----------------------------------------------------------------------------

Every file begins with:

    # =============================================================================
    # File: /opt/ansible-k3s-cluster/<path>/<filename>
    # =============================================================================

Ensures:

- files are readable out of context
- future maintainers can instantly locate files
- repo is self-navigating

# -----------------------------------------------------------------------------
# 6. Why Verification and Smoketest Playbooks?
# -----------------------------------------------------------------------------

These can be run anytime, even months later.

verify_builder.yml checks:

- builder user
- distccd disabled
- tmpfs state

verify_kernel.yml checks:

- kernel package existence
- kernel version on all nodes
- module presence

cluster-distcc-validate.yml checks:

- builder tmpfs
- builder distccd inactive
- worker distccd active
- worker override.conf
- worker symlinks
- gcc version
- PATH
- MTU
- FQDN
- distccd listening
- distcc dry-run

cluster-distcc-smoketest.yml performs:

- real distributed compile
- cc1 activity on workers
- distccd log inspection

# =============================================================================
# PLAYBOOKS
# =============================================================================

# --- DISTCC SUBSYSTEM --------------------------------------------------------

distccd-bootstrap.yml  
    Worker-only. Installs distccd, symlinks, override, directories.

builder-distccd-guard.yml  
    Builder-only. Ensures distccd disabled, tmpfs mounted, environment enforced.

worker-distccd-reset.yml  
    Worker-only. Stops k3s-agent, kills stale cc1, installs override, starts distccd.

cluster-distcc-validate.yml  
    Read-only validation of distcc subsystem.

cluster-distcc-smoketest.yml  
    Real distributed compile test.

distcc-mode-switch.yml  
    Switches cluster into DISTCC BUILD MODE.

cluster-mode-restore.yml  
    Returns cluster to K3S MODE.

# --- K3S SUBSYSTEM -----------------------------------------------------------

k3s-bootstrap.yml  
k3s-reset.yml  
k3s-validate.yml  

# =============================================================================
# WORKFLOWS
# =============================================================================

# 1. Bootstrap workers for distcc
    ansible-playbook playbooks/distccd-bootstrap.yml

# 2. Enter DISTCC BUILD MODE
    ansible-playbook playbooks/distcc-mode-switch.yml

# 3. Validate distcc
    ansible-playbook playbooks/cluster-distcc-validate.yml

# 4. Smoketest distcc
    ansible-playbook playbooks/cluster-distcc-smoketest.yml

# 5. Build kernel
    make -j14   (on builder)

# 6. Return to K3S MODE
    ansible-playbook playbooks/cluster-mode-restore.yml

# =============================================================================
# SUMMARY
# =============================================================================

This repository is the operating system for your cluster's automation:

- fully documented
- fully reproducible
- fully mode-aware
- fully distributed
- fully validated
- fully future-proof

Built for future maintainers, including future you.

# =============================================================================
# END OF FILE
# =============================================================================
