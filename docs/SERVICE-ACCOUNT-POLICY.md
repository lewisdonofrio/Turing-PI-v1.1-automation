# =============================================================================
# File: /opt/ansible-k3s-cluster/docs/SERVICE-ACCOUNT-POLICY.md
# =============================================================================
# Service Account Policy
# Rules for System, Daemon, and Application Accounts
# =============================================================================

This document defines the rules and expectations for all service accounts on the
Turing PI v1.1 cluster. Service accounts are non-human accounts used by system
services, daemons, and applications.

===============================================================================
1. Purpose of Service Accounts
===============================================================================

Service accounts exist to:
- run system daemons
- isolate privileges
- support k3s workloads
- provide least-privilege execution

They are NOT intended for:
- SSH access
- interactive login
- automation tasks
- sudo usage

===============================================================================
2. Allowed Service Accounts
===============================================================================

Examples of valid service accounts:
- root (locked for SSH)
- k3s
- prometheus
- grafana
- systemd-*
- nobody

===============================================================================
3. SSH Access Rules
===============================================================================

Service accounts:
- MUST NOT have SSH access
- MUST NOT have authorized_keys
- MUST NOT have passwords
- MUST NOT be used interactively

===============================================================================
4. Sudo Rules
===============================================================================

Service accounts:
- MUST NOT have sudo privileges
- MUST NOT appear in /etc/sudoers
- MUST NOT be added to privileged groups

===============================================================================
5. Password Policy
===============================================================================

Service accounts:
- MUST have locked passwords
- MUST NOT be assigned interactive shells
- SHOULD use /usr/bin/nologin or /bin/false

===============================================================================
6. Creation of New Service Accounts
===============================================================================

When creating a new service account:
1. Use useradd with:
       --system
       --no-create-home
       --shell /usr/bin/nologin
2. Do NOT assign a password
3. Do NOT add SSH keys
4. Document the account in this file

===============================================================================
7. Summary
===============================================================================

Service accounts are strictly controlled to maintain security, isolation, and
operational clarity across the cluster.

# =============================================================================
# End of File
# =============================================================================
