# =============================================================================
# File: /opt/cluster/docs/ARCHITECTURE.md
# =============================================================================
# Purpose:
#   High-level architecture overview of the hybrid automation model used by the
#   cluster. Defines the boundary between Ansible (cluster-wide orchestration)
#   and local scripts (single-node deterministic mode operations).
#   ASCII-only. Nano-safe. No tabs.
# =============================================================================

# =============================================================================
# OVERVIEW
# =============================================================================
The cluster uses a hybrid automation model:

1. Ansible for cluster-wide orchestration.
2. Local scripts for builder-mode, distcc environment setup, and kernel builds.

This separation ensures:
- deterministic builder environment
- reproducible kernel builds
- safe long-running operations
- idempotent cluster configuration
- clear operational boundaries

# =============================================================================
# ANSIBLE LAYER (CLUSTER-WIDE)
# =============================================================================
Ansible is used for:
- installing distccd on workers
- validating distcc cluster health
- smoketesting distributed compilation
- switching cluster modes
- bootstrapping k3s
- validating k3s cluster state
- deploying kernels
- verifying kernels
- rolling back kernels
- cluster-wide reporting and audits

Characteristics:
- declarative
- idempotent
- multi-node aware
- safe for configuration changes
- not used for long-running builds

Representative playbooks:
- playbooks/distccd-bootstrap.yml
- playbooks/distcc-mode-switch.yml
- playbooks/cluster-distcc-validate.yml
- playbooks/cluster-distcc-smoketest.yml
- playbooks/k3s-bootstrap.yml
- playbooks/cluster-mode-restore.yml
- playbooks/kernel-deploy.yml
- playbooks/kernel-verify.yml

# =============================================================================
# SCRIPT LAYER (SINGLE NODE)
# =============================================================================
Local scripts are used for:
- builder-mode entry
- environment validation
- tmpfs workspace management
- PATH and compiler overrides
- distcc wrapper enforcement
- kernel build orchestration

Characteristics:
- imperative
- deterministic
- environment-sensitive
- safe for long-running tasks
- executed only on the builder node

Representative scripts:
- /opt/cluster/scripts/builder-mode.sh
- /opt/cluster/scripts/builder-preflight.sh
- /opt/cluster/scripts/builder-tmpfs-ensure
- /opt/cluster/scripts/repo-validate.sh

# =============================================================================
# MODE SWITCHING
# =============================================================================
Two primary operational modes:

1. DISTCC BUILD MODE
   - Ansible prepares workers
   - Scripts prepare builder node
   - Kernel builds run locally using distcc

2. K3S MODE
   - Ansible restores cluster services
   - k3s workloads resume

Mode switching is explicit and controlled.

# =============================================================================
# KERNEL BUILD PIPELINE
# =============================================================================
1. Ansible prepares distcc cluster
2. builder-mode.sh prepares builder node
3. Kernel is built in /tmp/kernel-build
4. Kernel is deployed using Ansible
5. Kernel is validated using Ansible
6. Rollback available via Ansible

# =============================================================================
# DESIGN PRINCIPLES
# =============================================================================
- Deterministic operations
- Reproducible builds
- Clear separation of concerns
- No long-running tasks under Ansible
- Scripts handle environment-sensitive logic
- Ansible handles cluster-wide state
- ASCII-only documentation
- Single-file operational references

# =============================================================================
# END OF FILE
# =============================================================================
