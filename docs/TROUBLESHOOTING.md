# =============================================================================
# File: /opt/ansible-k3s-cluster/docs/TROUBLESHOOTING.md
# =============================================================================
# Troubleshooting Guide
# Common Issues, Root Causes, and Fix Procedures
# =============================================================================

This document provides solutions to common operational and automation issues
encountered in the Turing PI v1.1 cluster.

===============================================================================
1. SSH Failures
===============================================================================

Symptoms:
- "Host key verification failed"
- "Permission denied"
- Ansible unreachable errors

Fix:
1. Remove stale host keys:
       ssh-keygen -R kubenodeX
2. Re-scan keys:
       ssh-keyscan -H kubenode1 kubenode2 ... >> ~/.ssh/known_hosts
3. Test:
       ssh ansible@kubenodeX

===============================================================================
2. distccd Not Running
===============================================================================

Symptoms:
- Build stalls
- distcc jobs not distributed

Fix:
- Re-enter builder mode:
      ansible-playbook -i inventory/hosts site.yml -t builder_mode

===============================================================================
3. tmpfs Not Mounted
===============================================================================

Symptoms:
- Slow builds
- SD card thrashing

Fix:
- Re-enter builder mode
- Verify:
      mount | grep buildtmp

===============================================================================
4. Kernel Build Fails
===============================================================================

Symptoms:
- makepkg errors
- missing dependencies

Fix:
- Ensure PKGBUILD is valid
- Re-run builder mode
- Check artifacts directory

===============================================================================
5. Node Unreachable
===============================================================================

Symptoms:
- Ansible unreachable
- SSH timeout

Fix:
- Power cycle CM3+ module
- Verify network
- Re-run verification playbooks

===============================================================================
6. Summary
===============================================================================

This guide provides quick fixes for the most common issues in the cluster.

# =============================================================================
# End of File
# =============================================================================
