# DISTCC SUBSYSTEM
# =============================================================================
# Purpose:
#   Provide a reproducible, validated, distributed C/C++ compilation pipeline
#   across the Raspberry Pi CM3+/CM4 cluster. Ensures deterministic behavior,
#   clean state transitions, and safe operation at any time.

# Architecture:
#   - Builder node:
#       * Does NOT run distccd
#       * Runs distcc client only
#       * Mounts tmpfs at /tmp/kernel-build
#       * Orchestrates distributed builds
#
#   - Worker nodes:
#       * Run distccd
#       * Provide remote cc1 execution
#       * Maintain symlinks in /usr/lib/distcc
#       * Use systemd override for distccd

# Playbooks:
# =============================================================================

# 1. distccd-bootstrap.yml
#    - Worker-only
#    - Installs distccd
#    - Creates /usr/lib/distcc symlinks
#    - Installs systemd override
#    - Creates log and runtime directories
#    - Enables distccd (not started)

# 2. builder-distccd-guard.yml
#    - Builder-only
#    - Ensures distccd is stopped and disabled
#    - Enforces tmpfs mount integrity
#    - Enforces builder distcc environment

# 3. worker-distccd-reset.yml
#    - Worker-only
#    - Stops k3s-agent
#    - Stops distccd
#    - Kills stale cc1 and distccd processes
#    - Installs override.conf
#    - Reloads systemd
#    - Starts distccd

# 4. cluster-distcc-validate.yml
#    - Read-only validation
#    - Checks:
#        * Builder tmpfs state
#        * Builder distccd inactive
#        * Worker distccd active
#        * Worker override.conf present
#        * Worker symlinks present
#        * gcc version
#        * PATH
#        * MTU
#        * FQDN
#        * distccd listening on port 3632
#        * distcc dry-run

# 5. cluster-distcc-smoketest.yml
#    - Real distributed compile test
#    - Builder compiles hello.c via distcc
#    - Workers execute cc1
#    - Logs and cc1 activity verified

# 6. distcc-mode-switch.yml
#    - Switches cluster into DISTCC BUILD MODE
#    - Stops k3s-server and k3s-agent
#    - Enables tmpfs on builder
#    - Runs builder-distccd-guard.yml
#    - Runs worker-distccd-reset.yml

# Usage:
# =============================================================================

# Bootstrap workers:
#   ansible-playbook playbooks/distccd-bootstrap.yml

# Prepare builder:
#   ansible-playbook playbooks/builder-distccd-guard.yml

# Reset workers:
#   ansible-playbook playbooks/worker-distccd-reset.yml

# Validate cluster:
#   ansible-playbook playbooks/cluster-distcc-validate.yml

# Smoketest:
#   ansible-playbook playbooks/cluster-distcc-smoketest.yml

# Enter DISTCC BUILD MODE:
#   ansible-playbook playbooks/distcc-mode-switch.yml

# Notes:
#   - All playbooks are idempotent.
#   - All operations are ASCII-only.
#   - Safe to run at any time.
#   - Designed for reproducibility and operational clarity.
