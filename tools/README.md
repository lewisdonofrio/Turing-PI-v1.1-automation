# Tools Directory
# =============================================================================
# Path: /opt/ansible-k3s-cluster/tools/README.md
# Purpose:
#   Operational helper scripts for cluster maintenance, debugging, and
#   distributed kernel build verification.
# =============================================================================

## distcc-sanity-check.sh
Path:
  /opt/ansible-k3s-cluster/tools/distcc-sanity-check.sh

Purpose:
  Verify that distcc is actively distributing kernel build jobs.

Checks performed:
  - Active TCP connections to worker distccd instances
  - cc1 processes running on workers
  - distccd logs (last 5 entries)
  - Worker load averages
  - distccmon-text snapshot

Usage:
  bash distcc-sanity-check.sh


## panic-cleanup.sh
Path:
  /opt/ansible-k3s-cluster/tools/panic-cleanup.sh

Purpose:
  Safely terminate all processes spawned by a runaway kernel build or
  stuck Ansible SSH multiplexers.

Actions performed:
  - Kill cc1, gcc, g++, make
  - Kill ansible-playbook and python3 module runners
  - Kill SSH multiplexers
  - Kill sudo wrappers
  - Remove stale Ansible control sockets
  - Kill zombie parents
  - Restart sshd

Usage:
  bash panic-cleanup.sh
