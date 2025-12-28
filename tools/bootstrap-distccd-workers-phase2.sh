#!/bin/bash
# =============================================================================
# File: /opt/ansible-k3s-cluster/tools/bootstrap-distccd-workers-phase2.sh
# Purpose:
#   Phase 2 of distccd bootstrap:
#     - Re-exec systemd (must be done in a separate SSH session)
#     - Restart distccd
#     - Verify port 3632 is listening
#
#   This must be run AFTER Phase 1.
# =============================================================================

WORKERS="kubenode2 kubenode3 kubenode4 kubenode5 kubenode6 kubenode7"

echo "====================================================================="
echo " DISTCCD BOOTSTRAP PHASE 2 (systemd re-exec + restart)"
echo "====================================================================="
echo

for n in $WORKERS; do
    echo "----- $n -----"

    ssh "$n" "sudo bash -c '
        echo \">>> Re-executing systemd\"
        systemctl daemon-reexec

        echo \">>> Restarting distccd\"
        systemctl restart distccd

        echo \">>> Waiting for distccd to settle\"
        sleep 2

        echo \">>> Checking distccd status\"
        systemctl is-active distccd || echo \"WARNING: distccd not active\"

        echo \">>> Checking port 3632\"
        if ss -tnlp | grep -q \":3632\"; then
            echo \"distccd is LISTENING on port 3632\"
        else
            echo \"WARNING: distccd NOT listening on port 3632\"
            ss -tnlp || true
        fi
    '"

    echo
done

echo "====================================================================="
echo " PHASE 2 COMPLETE — DISTCCD SHOULD NOW BE LISTENING"
echo "====================================================================="
