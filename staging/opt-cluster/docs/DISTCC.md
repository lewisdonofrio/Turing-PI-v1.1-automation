# =============================================================================
# File: /opt/cluster/docs/DISTCC.md
# =============================================================================
# Purpose:
#   Operational reference for the distributed compilation subsystem. Defines
#   responsibilities, workflows, and commands for preparing, validating, and
#   using distcc across the cluster. ASCII-only. Nano-safe. No tabs.
# =============================================================================

# =============================================================================
# OVERVIEW
# =============================================================================
distcc provides distributed C/C++ compilation across the cluster. Workers run
distccd. The builder node uses distcc wrappers to distribute kernel builds.

distcc is orchestrated by:
- Ansible for cluster-wide operations
- Local scripts for builder-mode environment setup

# =============================================================================
# WORKER NODE OPERATIONS (ANSIBLE)
# =============================================================================

# Bootstrap distccd on all workers (first time only)
ansible-playbook playbooks/distccd-bootstrap.yml

# Reset distccd state on workers
ansible-playbook playbooks/cluster-distcc-reset.yml

# Validate distcc worker configuration
ansible-playbook playbooks/cluster-distcc-validate.yml

# Smoketest distributed compilation
ansible-playbook playbooks/cluster-distcc-smoketest.yml

# Monitor distcc cluster status
ansible-playbook playbooks/distcc-status.yml

# =============================================================================
# BUILDER NODE OPERATIONS (LOCAL SCRIPTS)
# =============================================================================

# Enter builder mode (preflight, tmpfs, environment)
 /opt/cluster/scripts/builder-mode.sh

# distcc wrapper directory (must be first in PATH)
/usr/lib/distcc/bin

# Compiler overrides (set by builder-mode)
CC="distcc gcc"
CXX="distcc g++"

# distcc hosts file (managed by Ansible)
/etc/distcc/hosts

# =============================================================================
# DISTCC VALIDATION COMMANDS (LOCAL)
# =============================================================================

# Show configured hosts
distcc --show-hosts

# Show job distribution
distccmon-text 1

# Test compile
echo 'int main(){return 0;}' > test.c
distcc gcc -c test.c

# =============================================================================
# KERNEL BUILD USING DISTCC
# =============================================================================

# Enter workspace
cd /tmp/kernel-build

# Build kernel using distributed compilation
make -j14

# Monitor job distribution
distccmon-text 1

# =============================================================================
# TROUBLESHOOTING
# =============================================================================

# Workers unreachable
ansible-playbook playbooks/cluster-distcc-validate.yml

# Builder environment incorrect
/opt/cluster/scripts/builder-preflight.sh

# PATH or CC overrides missing
/opt/cluster/scripts/builder-mode.sh

# =============================================================================
# END OF FILE
# =============================================================================
