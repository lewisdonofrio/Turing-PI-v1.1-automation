# =============================================================================
# File: /opt/ansible-k3s-cluster/docs/STORAGE-LAYOUT.md
# =============================================================================
# Storage Layout
# Directory Structure and Storage Responsibilities
# =============================================================================

This document defines the storage layout for the Turing PI v1.1 cluster.

===============================================================================
1. Key Directories
===============================================================================

/opt/ansible-k3s-cluster
    - automation repository
    - playbooks
    - roles
    - docs
    - artifacts

/home/builder/buildtmp
    - tmpfs build directory

/var/lib/rancher/k3s
    - k3s data store

/etc
    - system configuration

===============================================================================
2. tmpfs Usage
===============================================================================

tmpfs is used for:
- kernel builds
- distcc temporary files
- reducing SD card wear

===============================================================================
3. Artifacts Directory
===============================================================================

artifacts/ stores:
- kernel packages
- build logs
- versioned outputs

===============================================================================
4. Backup Targets
===============================================================================

Back up:
- artifacts/
- inventory/
- group_vars/
- docs/
- site.yml and playbooks

===============================================================================
5. Summary
===============================================================================

This layout ensures reproducibility, clarity, and maintainability.

# =============================================================================
# End of File
# =============================================================================
