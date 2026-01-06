# =============================================================================
# File: /opt/cluster/docs/KERNEL-BUILD.md
# =============================================================================
# Purpose:
#   Operational reference for building, validating, and deploying Linux kernels
#   using the hybrid Ansible + script automation model. ASCII-only. Nano-safe.
#   No tabs.
# =============================================================================

# =============================================================================
# OVERVIEW
# =============================================================================
Kernel builds run on the builder node using:
- builder-mode.sh for environment setup
- distcc for distributed compilation
- Ansible for deployment and validation

Builds do NOT run under Ansible due to long runtimes and environment sensitivity.

# =============================================================================
# PREPARATION
# =============================================================================

# 1. Ensure cluster connectivity
ansible all -m ping

# 2. Prepare distcc workers (first time only)
ansible-playbook playbooks/distccd-bootstrap.yml

# 3. Switch cluster into distcc mode
ansible-playbook playbooks/distcc-mode-switch.yml

# 4. Validate distcc cluster
ansible-playbook playbooks/cluster-distcc-validate.yml

# 5. Enter builder mode on builder node
/opt/cluster/scripts/builder-mode.sh

# =============================================================================
# WORKSPACE SETUP
# =============================================================================

# Enter workspace
cd /tmp/kernel-build

# Clone kernel source (example)
git clone --depth=1 https://github.com/raspberrypi/linux kernel
cd kernel

# Import kernel config (example)
cp /opt/cluster/kernel/config .config

# Or generate default config
# make bcm2711_defconfig

# =============================================================================
# BUILD
# =============================================================================

# Build kernel using distcc
make -j14

# Monitor distributed jobs
distccmon-text 1

# =============================================================================
# INSTALL (BUILDER NODE)
# =============================================================================

# Install modules
sudo make modules_install

# Install kernel
sudo make install

# =============================================================================
# DEPLOY TO CLUSTER (ANSIBLE)
# =============================================================================

# Deploy kernel to all nodes
ansible-playbook playbooks/kernel-deploy.yml

# Validate kernel across cluster
ansible-playbook playbooks/kernel-verify.yml

# Rollback if required
ansible-playbook playbooks/kernel-rollback.yml

# =============================================================================
# CLEANUP
# =============================================================================

# Optional: clean workspace
rm -rf /tmp/kernel-build/*

# =============================================================================
# END OF FILE
# =============================================================================
