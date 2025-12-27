# =============================================================================
# File: /opt/ansible-k3s-cluster/docs/NODE-REPLACEMENT.md
# =============================================================================
# Node Replacement Guide
# How to Replace a CM3+ Module in the Cluster
# =============================================================================

This guide explains how to replace a failed or new CM3+ module.

===============================================================================
1. Physical Replacement
===============================================================================

1. Power down the cluster
2. Remove failed CM3+ module
3. Insert replacement module
4. Power on the cluster

===============================================================================
2. Bootstrap the New Node
===============================================================================

1. Assign hostname (kubenodeX)
2. Configure network
3. Create ansible user
4. Add SSH keys

===============================================================================
3. Add Node to Inventory
===============================================================================

Edit:
    inventory/hosts

Add entry for new node.

===============================================================================
4. Run Bootstrap Playbooks
===============================================================================

Run:
    ansible-playbook -i inventory/hosts verify_builder.yml

Then:
    ansible-playbook -i inventory/hosts site.yml -t k3s_mode

===============================================================================
5. Verify Node Health
===============================================================================

Run:
    ansible-playbook -i inventory/hosts verify_kernel.yml

===============================================================================
6. Summary
===============================================================================

This guide ensures consistent and reproducible node replacement.

# =============================================================================
# End of File
# =============================================================================
