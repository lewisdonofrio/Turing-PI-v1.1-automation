#!/bin/bash
# =============================================================================
# File: /opt/ansible-k3s-cluster/tools/bootstrap-distccd-workers-phase1.sh
# Purpose:
#   Phase 1 of distccd bootstrap:
#     - Install gcc and distccd
#     - Write systemd override with hardcoded ExecStart
#     - Reload systemd (NOT re-exec)
#
#   Phase 2 must be run afterward to re-exec systemd and restart distccd.
# =============================================================================

WORKERS="kubenode2 kubenode3 kubenode4 kubenode5 kubenode6 kubenode7"
ALLOW_SUBNET="192.168.29.0/24"
JOBS=4

echo "====================================================================="
echo " DISTCCD BOOTSTRAP PHASE 1 (apply override)"
echo "====================================================================="
echo

for n in $WORKERS; do
    echo "----- $n -----"

    ssh "$n" "sudo bash -c '
        set -e

        echo \">>> Ensuring gcc is installed\"
        pacman -Q gcc >/dev/null 2>&1 || pacman -Sy --noconfirm gcc

        echo \">>> Ensuring distccd is installed\"
        pacman -Q distcc >/dev/null 2>&1 || pacman -Sy --noconfirm distcc

        echo \">>> Writing systemd override (hardcoded ExecStart)\"
        mkdir -p /etc/systemd/system/distccd.service.d

        cat > /etc/systemd/system/distccd.service.d/override.conf <<EOF
[Service]
ExecStart=
ExecStart=/usr/bin/distccd --no-detach --allow $ALLOW_SUBNET --jobs $JOBS
EOF

        echo \">>> Reloading systemd (NOT re-exec)\"
        systemctl daemon-reload
    '"

    echo
done

echo "====================================================================="
echo " PHASE 1 COMPLETE — NOW RUN PHASE 2"
echo "====================================================================="
