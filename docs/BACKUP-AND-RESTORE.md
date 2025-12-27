# =============================================================================
# File: /opt/ansible-k3s-cluster/docs/BACKUP-AND-RESTORE.md
# =============================================================================
# Backup and Restore Guide
# Procedures for Protecting and Recovering Cluster State
# =============================================================================

This document defines backup and restore procedures for the Turing PI v1.1
cluster.

===============================================================================
1. What to Back Up
===============================================================================

Back up the following:
- artifacts/ (kernel packages)
- inventory/
- group_vars/
- site.yml and playbooks
- docs/
- k3s manifests (if used)

===============================================================================
2. Backup Procedure
===============================================================================

1. Create backup directory
2. Copy repository
3. Copy artifacts
4. Store off-device

Example:

    tar -czf cluster-backup.tar.gz /opt/ansible-k3s-cluster

===============================================================================
3. Restore Procedure
===============================================================================

1. Extract backup
2. Verify inventory
3. Re-run verification playbooks
4. Re-deploy kernel if needed

===============================================================================
4. Node-Level Backup
===============================================================================

For each node:
- back up /etc
- back up /var/lib/rancher/k3s (if using local storage)
- back up custom configs

===============================================================================
5. Disaster Recovery
===============================================================================

If a node is lost:
1. Replace CM3+ module
2. Follow NODE-REPLACEMENT.md
3. Re-deploy kernel
4. Rejoin k3s cluster

===============================================================================
6. Summary
===============================================================================

This guide ensures the cluster can be backed up and restored reliably.

# =============================================================================
# End of File
# =============================================================================
