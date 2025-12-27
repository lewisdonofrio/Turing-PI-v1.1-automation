# =============================================================================
# File: /opt/ansible-k3s-cluster/docs/SECURITY-HARDENING.md
# =============================================================================
# Security Hardening Guide
# Recommendations for Strengthening Cluster Security
# =============================================================================

This document provides security hardening recommendations for the Turing PI v1.1
cluster. These practices reduce attack surface, improve isolation, and ensure
long-term operational safety.

===============================================================================
1. SSH Hardening
===============================================================================

- Disable root SSH login
- Disable password authentication after bootstrap
- Use SSH keys for ansible user
- Restrict SSH to kubenode1 only
- Enforce strict host key checking

===============================================================================
2. User Account Hardening
===============================================================================

- builder user exists only on kubenode1
- ansible user exists on all nodes
- service accounts remain locked
- no interactive shells for system accounts

===============================================================================
3. Sudo Hardening
===============================================================================

- ansible user has passwordless sudo
- builder user has local sudo only
- service accounts have no sudo privileges

===============================================================================
4. File System Hardening
===============================================================================

- use tmpfs for builds
- restrict /etc permissions
- restrict /var/lib/rancher/k3s permissions
- ensure artifacts/ is writable only by builder

===============================================================================
5. Network Hardening
===============================================================================

- use wired Ethernet only
- restrict inbound traffic to SSH and k3s ports
- avoid exposing nodes to the public internet

===============================================================================
6. Kernel Hardening
===============================================================================

- use custom kernel with minimal modules
- disable unused subsystems
- enable security options in .config

===============================================================================
7. Summary
===============================================================================

These practices strengthen the cluster against unauthorized access and misuse.

# =============================================================================
# End of File
# =============================================================================
