#!/bin/bash
# =============================================================================
# File: /opt/ansible-k3s-cluster/tools/distcc-sanity-check.sh
# Purpose:
#   Verify that distcc is actively distributing kernel build jobs.
#   Checks:
#     - cc1 processes on workers
#     - distccd logs
#     - TCP connections to port 3632
#     - load averages
#     - distccmon-text summary
# =============================================================================

WORKERS="kubenode2 kubenode3 kubenode4 kubenode5 kubenode6 kubenode7"

echo "====================================================================="
echo " DISTCC SANITY CHECK"
echo "====================================================================="
echo

echo ">>> Checking TCP connections from kubenode1 to workers (port 3632)"
echo
for n in $WORKERS; do
    echo "----- $n -----"
    ss -tn | grep "$n:3632" || echo "no active distcc connection"
    echo
done

echo ">>> Checking cc1 processes on workers"
echo
for n in $WORKERS; do
    echo "----- $n -----"
    ssh "$n" "pgrep -af cc1 || echo 'no cc1 processes'"
    echo
done

echo ">>> Checking distccd logs on workers"
echo
for n in $WORKERS; do
    echo "----- $n -----"
    ssh "$n" "sudo journalctl -u distccd -n 5 --no-pager"
    echo
done

echo ">>> Checking load averages on workers"
echo
for n in $WORKERS; do
    echo "----- $n -----"
    ssh "$n" "uptime"
    echo
done

echo ">>> distccmon-text (5 second snapshot)"
echo
distccmon-text 5
echo

echo "====================================================================="
echo " DISTCC SANITY CHECK COMPLETE"
echo "====================================================================="
