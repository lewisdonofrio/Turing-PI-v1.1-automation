# =============================================================================
# File: /opt/ansible-k3s-cluster/docs/CLUSTER-ACCESS-POLICY.md
# =============================================================================
# Turing PI v1.1 Cluster Access Policy
# User Accounts, SSH Rules, Permissions, and Operational Boundaries
# =============================================================================

This document defines the official access model for the Turing PI v1.1 cluster.
It describes which users exist, what they are allowed to do, how SSH access is
managed, and how automation interacts with the system. This file is intended for
future maintainers, auditors, and anyone onboarding into cluster operations.

===============================================================================
1. User Classes
===============================================================================

The cluster uses three categories of users:

1. Automation User (ansible)
2. Local Build Orchestrator (builder)
3. System and Service Accounts (root, k3s, prometheus, grafana, etc.)

Each class has strict boundaries and responsibilities.

-------------------------------------------------------------------------------
1.1 ansible (Automation User)
-------------------------------------------------------------------------------

- Exists on ALL nodes.
- Has passwordless sudo.
- Has SSH key-based access from kubenode1.
- Is the ONLY user Ansible should ever SSH as.
- Used for:
  - running playbooks
  - distributed kernel builds
  - configuration management
  - verification tasks

ansible MUST always be functional across the entire cluster.

-------------------------------------------------------------------------------
1.2 builder (Local Build Orchestrator)
-------------------------------------------------------------------------------

- Exists ONLY on kubenode1.
- Does NOT exist on kubenode2–7.
- Does NOT have SSH access to other nodes.
- Used for:
  - running Ansible commands locally
  - orchestrating distributed kernel builds
  - maintaining the automation repository

builder is a local-only operator account and should never be used remotely.

-------------------------------------------------------------------------------
1.3 System and Service Accounts
-------------------------------------------------------------------------------

Examples:
- root
- k3s
- prometheus
- grafana
- systemd-*
- nobody

Rules:
- MUST NOT have SSH access.
- MUST NOT have passwords.
- MUST NOT be used for automation.
- MUST NOT be used interactively.

These accounts exist only for system services.

===============================================================================
2. SSH Access Rules
===============================================================================

SSH access is intentionally restricted for security, reproducibility, and
operational clarity.

-------------------------------------------------------------------------------
2.1 Allowed SSH Access
-------------------------------------------------------------------------------

builder@kubenode1:
    - local shell only
    - no remote SSH

ansible@kubenodeX:
    - SSH allowed from kubenode1
    - key-based authentication preferred
    - password fallback allowed during bootstrap

-------------------------------------------------------------------------------
2.2 Forbidden SSH Access
-------------------------------------------------------------------------------

- root → any node
- builder → kubenode2–7
- service accounts → any node
- passwordless SSH for any user except ansible

-------------------------------------------------------------------------------
2.3 Host Key Requirements
-------------------------------------------------------------------------------

The file:
    /home/builder/.ssh/known_hosts

MUST contain valid host keys for:
    kubenode1
    kubenode2
    kubenode3
    kubenode4
    kubenode5
    kubenode6
    kubenode7

This ensures Ansible can connect without prompting.

===============================================================================
3. Operational Boundaries
===============================================================================

-------------------------------------------------------------------------------
3.1 builder Responsibilities
-------------------------------------------------------------------------------

- Run all Ansible commands.
- Maintain the automation repository.
- Trigger distributed kernel builds.
- Manage documentation.
- Never SSH into other nodes.

-------------------------------------------------------------------------------
3.2 ansible Responsibilities
-------------------------------------------------------------------------------

- Execute all remote tasks.
- Apply configuration changes.
- Perform verification checks.
- Deploy and reboot nodes.
- Never be used interactively except for debugging.

-------------------------------------------------------------------------------
3.3 Service Account Responsibilities
-------------------------------------------------------------------------------

- Run their respective daemons.
- Never be used for SSH.
- Never be used for automation.

===============================================================================
4. Password and Key Management
===============================================================================

- ansible user may temporarily use a password during bootstrap.
- ansible user should transition to SSH key-based auth.
- builder user should use SSH keys only for GitHub.
- root and service accounts must remain locked.

===============================================================================
5. Future Extensions
===============================================================================

This document may expand to include:

- RBAC for additional service accounts
- onboarding procedures for new maintainers
- SSH key rotation policies
- audit and compliance requirements

===============================================================================
6. Summary
===============================================================================

- builder is local-only on kubenode1.
- ansible is the only remote automation user.
- service accounts never SSH.
- SSH keys must be present for all kubenode hosts.
- This policy ensures security, clarity, and reproducibility.

# =============================================================================
# End of File
# =============================================================================
