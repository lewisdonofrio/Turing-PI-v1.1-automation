# =============================================================================
# File: /opt/ansible-k3s-cluster/docs/CLUSTER-LIFECYCLE.md
# =============================================================================
# Cluster Lifecycle
# Provisioning, Maintenance, Upgrades, and Decommissioning
# =============================================================================

This document defines the lifecycle of the Turing PI v1.1 cluster from initial
provisioning to decommissioning.

===============================================================================
1. Provisioning
===============================================================================

1. Install OS on CM3+ modules
2. Assign hostnames
3. Configure network
4. Create ansible user
5. Add SSH keys
6. Clone automation repo

===============================================================================
2. Bootstrap
===============================================================================

1. Run verification playbooks
2. Enter k3s mode
3. Deploy workloads

===============================================================================
3. Maintenance
===============================================================================

- kernel updates
- documentation updates
- node replacements
- security hardening

===============================================================================
4. Upgrades
===============================================================================

1. Upgrade kernel
2. Upgrade k3s
3. Upgrade automation roles
4. Validate with verification playbooks

===============================================================================
5. Decommissioning
===============================================================================

1. Drain node
2. Remove from inventory
3. Wipe storage
4. Remove SSH keys

===============================================================================
6. Summary
===============================================================================

This lifecycle ensures predictable long-term cluster management.

# =============================================================================
# End of File
# =============================================================================
