#!/bin/bash
# =============================================================================
# File: /opt/ansible-k3s-cluster/tools/fix-ssh-workers.sh
# Purpose:
#   Fix SSH connectivity issues between kubenode1 (ansible user) and all
#   worker nodes. This script:
#     - Removes stale known_hosts fingerprints
#     - Auto-accepts new host keys
#     - Ensures passwordless SSH works
#     - Cleans up SSH multiplexers
#     - Verifies connectivity to each worker
#
# Usage:
#   bash /opt/ansible-k3s-cluster/tools/fix-ssh-workers.sh
# =============================================================================

WORKERS="kubenode2 kubenode3 kubenode4 kubenode5 kubenode6 kubenode7"
KNOWN_HOSTS="/home/ansible/.ssh/known_hosts"
SSH_DIR="/home/ansible/.ssh"

echo "====================================================================="
echo " FIXING SSH CONNECTIVITY TO WORKER NODES"
echo "====================================================================="
echo

# Ensure .ssh directory exists
mkdir -p "$SSH_DIR"
chmod 700 "$SSH_DIR"

# Ensure known_hosts exists
touch "$KNOWN_HOSTS"
chmod 600 "$KNOWN_HOSTS"

echo ">>> Cleaning stale SSH multiplexers"
rm -f /home/ansible/.ansible/cp/* 2>/dev/null

echo

for n in $WORKERS; do
    echo "----- $n -----"

    # Remove stale fingerprints
    echo ">>> Removing stale fingerprints for $n"
    ssh-keygen -R "$n" >/dev/null 2>&1
    ssh-keygen -R "$(getent hosts $n | awk '{print $1}')" >/dev/null 2>&1

    # Auto-accept new host key
    echo ">>> Adding fresh host key for $n"
    ssh -o StrictHostKeyChecking=accept-new -o BatchMode=no "$n" "echo 'SSH OK'" 2>/dev/null

    # Verify passwordless SSH
    echo ">>> Verifying passwordless SSH"
    ssh -o BatchMode=yes "$n" "echo 'Passwordless SSH working'" 2>/dev/null || \
        echo "WARNING: Passwordless SSH may NOT be working"

    echo
done

echo "====================================================================="
echo " SSH FIX COMPLETE"
echo "====================================================================="
