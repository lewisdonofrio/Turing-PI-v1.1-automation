#!/usr/bin/env bash
#
# =====================================================================
#  /home/builder/scripts/kernel-cluster-dashboard.sh
#
#  Purpose:
#    Display real-time cluster load and distcc activity across all
#    worker nodes. Intended for use in a tmux pane during distributed
#    kernel builds.
#
#  Notes:
#    - ASCII-only, nano-safe, deterministic.
#    - No tabs, no Unicode, no timestamps.
#    - Must be run as builder on kubenode1.
#    - Requires passwordless SSH to all worker nodes.
# =====================================================================

set -euo pipefail

# ---------------------------------------------------------------------
#  Environment validation
# ---------------------------------------------------------------------

if [ "$(whoami)" != "builder" ]; then
    echo "ERROR: Must run as builder user"
    exit 1
fi

if [ "$(hostname)" != "kubenode1" ]; then
    echo "ERROR: Must run on kubenode1"
    exit 1
fi

# ---------------------------------------------------------------------
#  Worker list
# ---------------------------------------------------------------------

WORKERS="
kubenode1.home.lab
kubenode2.home.lab
kubenode3.home.lab
kubenode4.home.lab
kubenode5.home.lab
kubenode6.home.lab
kubenode7.home.lab
"

# ---------------------------------------------------------------------
#  Dashboard loop
# ---------------------------------------------------------------------

while true; do
    clear
    echo "============================================================"
    echo "  Cluster Load and Distcc Dashboard"
    echo "============================================================"
    echo

    # Distcc summary (local)
    echo "distcc jobs (local):"
    distccmon-text 1 | sed 's/^/  /'
    echo

    # Worker loads
    echo "Worker CPU loads:"
    for NODE in $WORKERS; do
        LOAD=$(ssh "$NODE" "cat /proc/loadavg" || echo "unreachable")
        echo "  $NODE  $LOAD"
    done

    echo
    echo "Refreshing in 2 seconds..."
    sleep 2
done
