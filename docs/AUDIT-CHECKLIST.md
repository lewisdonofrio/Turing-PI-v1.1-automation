# =============================================================================
# File: /opt/ansible-k3s-cluster/docs/AUDIT-CHECKLIST.md
# =============================================================================
# Audit Checklist
# Verification Steps for Cluster Compliance and Health
# =============================================================================

This checklist provides a repeatable audit process for verifying cluster health,
security, and configuration integrity.

===============================================================================
1. User Accounts
===============================================================================

- builder exists only on kubenode1
- ansible exists on all nodes
- service accounts locked
- no unexpected users

===============================================================================
2. SSH Configuration
===============================================================================

- root SSH disabled
- password auth disabled (after bootstrap)
- SSH keys present for ansible
- known_hosts populated

===============================================================================
3. Sudo Configuration
===============================================================================

- ansible has passwordless sudo
- builder has local sudo only
- no service accounts in sudoers

===============================================================================
4. File System Integrity
===============================================================================

- tmpfs mounted during builds
- artifacts directory intact
- no unexpected writable directories

===============================================================================
5. Kernel Verification
===============================================================================

Run:
    ansible-playbook -i inventory/hosts verify_kernel.yml

===============================================================================
6. k3s Verification
===============================================================================

Run:
    kubectl get nodes
    kubectl get pods -A

===============================================================================
7. Documentation Check
===============================================================================

Ensure:
- docs/ is complete
- all files ASCII-only
- all operational procedures documented

===============================================================================
8. Summary
===============================================================================

This checklist ensures the cluster remains secure, consistent, and maintainable.

# =============================================================================
# End of File
# =============================================================================
