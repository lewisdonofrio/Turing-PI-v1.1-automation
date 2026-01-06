# =============================================================================
# File: /opt/cluster/docs/QUICKSTART.md
# =============================================================================
# Purpose:
#   Ultra-short operational reference for cluster mode switching, distcc
#   operations, and kernel build workflow. ASCII-only. Nano-safe. No tabs.
# =============================================================================

# =============================================================================
# DISTCC BUILD MODE (distributed kernel compilation)
# =============================================================================

# 1. Verify cluster connectivity
ansible all -m ping

# 2. Bootstrap distccd workers (first time only)
ansible-playbook playbooks/distccd-bootstrap.yml

# 3. Switch cluster into distcc mode
ansible-playbook playbooks/distcc-mode-switch.yml

# 4. Validate distcc cluster health
ansible-playbook playbooks/cluster-distcc-validate.yml

# 5. Smoketest distributed compilation
ansible-playbook playbooks/cluster-distcc-smoketest.yml

# 6. Enter builder mode on the builder node
/opt/cluster/scripts/builder-mode.sh

# 7. Build kernel (example)
cd /tmp/kernel-build
make -j14

# =============================================================================
# K3S MODE (cluster workloads)
# =============================================================================

# 1. Verify cluster connectivity
ansible all -m ping

# 2. Bootstrap k3s cluster (first time only)
ansible-playbook playbooks/k3s-bootstrap.yml

# 3. Restore cluster mode
ansible-playbook playbooks/cluster-mode-restore.yml

# 4. Validate k3s cluster
ansible-playbook playbooks/k3s-validate.yml

# =============================================================================
# KERNEL DEPLOYMENT (post-build)
# =============================================================================

# 1. Deploy kernel to cluster
ansible-playbook playbooks/kernel-deploy.yml

# 2. Validate kernel across nodes
ansible-playbook playbooks/kernel-verify.yml

# 3. Rollback if required
ansible-playbook playbooks/kernel-rollback.yml

# =============================================================================
# END OF FILE
# =============================================================================
