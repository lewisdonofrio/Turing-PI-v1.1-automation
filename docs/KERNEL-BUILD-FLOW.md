# =============================================================================
# File: /opt/ansible-k3s-cluster/docs/KERNEL-BUILD-FLOW.md
# =============================================================================
# Kernel Build Flow
# End-to-End Distributed Kernel Build Pipeline
# =============================================================================

This document describes the complete kernel build flow used by the cluster.

===============================================================================
1. Preparation
===============================================================================

- builder user triggers build
- ansible user executes remote tasks
- tmpfs mounted on all nodes
- distccd started everywhere

===============================================================================
2. Source Sync
===============================================================================

- PKGBUILD copied to all nodes
- patches synced
- kernel source extracted

===============================================================================
3. Configuration
===============================================================================

- .config generated
- options applied
- configuration validated

===============================================================================
4. Distributed Compilation
===============================================================================

- distcc distributes compile jobs
- kubenode1 coordinates
- workers compile in parallel

===============================================================================
5. Packaging
===============================================================================

- kubenode1 runs:
      makepkg -s
- artifacts stored in:
      artifacts/

===============================================================================
6. Deployment
===============================================================================

- kernel installed on all nodes
- modules updated
- bootloader updated

===============================================================================
7. Reboot and Verification
===============================================================================

- nodes reboot serially
- verify_kernel.yml confirms success

===============================================================================
8. Summary
===============================================================================

This flow ensures reproducible, distributed kernel builds across the cluster.

# =============================================================================
# End of File
# =============================================================================
