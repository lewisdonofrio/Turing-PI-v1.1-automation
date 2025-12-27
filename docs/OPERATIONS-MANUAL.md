# =============================================================================
# File: /opt/ansible-k3s-cluster/docs/OPERATIONS-MANUAL.md
# =============================================================================
# Operations Manual
# Daily, Weekly, Monthly, and Emergency Procedures
# =============================================================================

This manual defines the operational responsibilities and procedures for managing
the Turing PI v1.1 cluster.

===============================================================================
1. Daily Operations
===============================================================================

1. Verify cluster health:
       kubectl get nodes
       kubectl get pods -A

2. Verify automation health:
       ansible-playbook -i inventory/hosts verify_builder.yml

3. Check disk usage:
       df -h

4. Check system logs:
       journalctl -p 3 -xb

===============================================================================
2. Weekly Operations
===============================================================================

1. Update documentation
2. Review artifacts directory
3. Check for kernel updates
4. Run audit checklist:
       docs/AUDIT-CHECKLIST.md

===============================================================================
3. Monthly Operations
===============================================================================

1. Back up repository:
       tar -czf cluster-backup.tar.gz /opt/ansible-k3s-cluster

2. Back up k3s manifests
3. Review service account policy
4. Verify SSH keys

===============================================================================
4. Emergency Operations
===============================================================================

1. Node unreachable:
       power cycle CM3+
       re-run verification playbooks

2. Kernel failure:
       redeploy previous kernel from artifacts/

3. k3s failure:
       restart service
       check logs

===============================================================================
5. Summary
===============================================================================

This manual provides a complete operational workflow for the cluster.

# =============================================================================
# End of File
# =============================================================================
