# =============================================================================
# File: /opt/ansible-k3s-cluster/QUICKSTART.md
# =============================================================================
# QUICKSTART GUIDE
# =============================================================================
# Purpose:
#   Provide a fast, deterministic workflow for bringing the cluster from
#   cold power-on into either:
#     - DISTCC BUILD MODE (for kernel builds)
#     - K3S MODE (for normal cluster operation)
#
#   All commands are ASCII-only, idempotent, and safe to run at any time.

# =============================================================================
# PREREQUISITES
# =============================================================================
# - All nodes powered on
# - SSH reachable
# - Inventory correct at: inventory/hosts

# =============================================================================
# DISTCC BUILD MODE QUICKSTART
# =============================================================================
# Goal:
#   Prepare the cluster for distributed kernel compilation.

# Steps:
# -----------------------------------------------------------------------------

1. Verify connectivity
ansible -i inventory/hosts all -m ping

2. Bootstrap distcc workers (first-time only)
ansible-playbook -i inventory/hosts playbooks/distccd-bootstrap.yml

3. Enter DISTCC BUILD MODE
ansible-playbook -i inventory/hosts playbooks/distcc-mode-switch.yml
# This performs:
# - Stop k3s-server (builder)
# - Stop k3s-agent (workers)
# - Mount tmpfs on builder
# - Disable distccd on builder
# - Reset distccd on workers
# - Start distccd on workers

4. Validate distcc subsystem
ansible-playbook -i inventory/hosts playbooks/cluster-distcc-validate.yml

5. Run smoketest
ansible-playbook -i inventory/hosts playbooks/cluster-distcc-smoketest.yml

# READY FOR NEXT STEP:
# Run kernel build on builder:
make -j14

# =============================================================================
# K3S MODE QUICKSTART
# =============================================================================
# Goal:
#   Prepare the cluster for normal Kubernetes operation.

# Steps:
# -----------------------------------------------------------------------------

1. Verify connectivity
ansible -i inventory/hosts all -m ping

2. Bootstrap k3s (first-time only)
ansible-playbook -i inventory/hosts playbooks/k3s-bootstrap.yml

3. Restore cluster to K3S MODE
ansible-playbook -i inventory/hosts playbooks/cluster-mode-restore.yml
# This performs:
# - Stop distccd on workers
# - Disable distccd on workers
# - Unmount tmpfs on builder
# - Start k3s-agent on workers
# - Start k3s-server on builder

4. Validate k3s subsystem
ansible-playbook -i inventory/hosts playbooks/k3s-validate.yml

# READY FOR NEXT STEP:
# Cluster is ready for workloads:
kubectl get nodes

# =============================================================================
# ULTRA-SHORT REFERENCE
# =============================================================================

## DISTCC BUILD MODE
ansible all -m ping
ansible-playbook playbooks/distccd-bootstrap.yml   # first time only
ansible-playbook playbooks/distcc-mode-switch.yml
ansible-playbook playbooks/cluster-distcc-validate.yml
ansible-playbook playbooks/cluster-distcc-smoketest.yml
#  -> run make -j14 on builder

## K3S MODE
ansible all -m ping
ansible-playbook playbooks/k3s-bootstrap.yml       # first time only
ansible-playbook playbooks/cluster-mode-restore.yml
ansible-playbook playbooks/k3s-validate.yml
# â-> cluster ready for workloads

# =============================================================================
# END OF FILE
# =============================================================================
