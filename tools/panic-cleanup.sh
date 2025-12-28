#!/bin/bash
# =============================================================================
# File: /opt/ansible-k3s-cluster/tools/panic-cleanup.sh
# Purpose:
#   Safely terminate all processes spawned by a runaway kernel build or
#   stuck Ansible SSH multiplexers.
#   Kills:
#     - cc1, cc1plus, gcc, g++, make
#     - ansible-playbook
#     - python3 module runners
#     - ssh multiplexers
#     - sudo wrappers
#     - zombie parents
#     - stale Ansible control sockets
# =============================================================================

echo "====================================================================="
echo " PANIC CLEANUP STARTED"
echo "====================================================================="

echo ">>> Killing compiler processes"
sudo killall -9 cc1 cc1plus gcc g++ make 2>/dev/null

echo ">>> Killing Ansible processes"
sudo killall -9 ansible-playbook python3 2>/dev/null

echo ">>> Killing SSH multiplexers"
sudo killall -9 ssh 2>/dev/null

echo ">>> Killing sudo wrappers"
sudo killall -9 sudo 2>/dev/null

echo ">>> Cleaning Ansible control sockets"
rm -f /home/ansible/.ansible/cp/* 2>/dev/null

echo ">>> Checking for zombies"
ZOMBIES=$(ps -eo pid,ppid,stat,comm | awk '$3=="Z"{print $1,$2}')
if [ -n "$ZOMBIES" ]; then
    echo "$ZOMBIES" | while read -r pid ppid; do
        echo "Killing zombie parent PID $ppid"
        sudo kill -9 "$ppid" 2>/dev/null
    done
else
    echo "No zombies found"
fi

echo ">>> Restarting sshd (optional but recommended)"
sudo systemctl restart sshd

echo
echo "====================================================================="
echo " PANIC CLEANUP COMPLETE"
echo "====================================================================="
