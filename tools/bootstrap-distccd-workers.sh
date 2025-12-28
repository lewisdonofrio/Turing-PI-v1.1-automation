#!/bin/bash
# =============================================================================
# File: /opt/ansible-k3s-cluster/tools/bootstrap-distccd-workers.sh
# Purpose:
#   Fully bootstrap all worker nodes for distributed compilation on
#   ArchLinuxARM. This script:
#     - Ensures gcc is installed (for cc1)
#     - Ensures distccd is installed
#     - Applies the correct systemd override for distccd
#     - Forces systemd to reload AND re-exec (required on ArchLinuxARM)
#     - Sets the correct --allow subnet and --jobs value
#     - Restarts distccd
#     - Verifies distccd is listening on port 3632
#
# Usage:
#   bash /opt/ansible-k3s-cluster/tools/bootstrap-distccd-workers.sh
# =============================================================================

WORKERS="kubenode2 kubenode3 kubenode4 kubenode5 kubenode6 kubenode7"
ALLOW_SUBNET="192.168.29.0/24"
JOBS=4

echo "====================================================================="
echo " BOOTSTRAPPING DISTCCD WORKER NODES (ArchLinuxARM)"
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

        echo \">>> Creating systemd override for distccd\"
        mkdir -p /etc/systemd/system/distccd.service.d

        cat > /etc/systemd/system/distccd.service.d/override.conf <<EOF
[Service]
Environment=\"DISTCC_ARGS=--allow $ALLOW_SUBNET --jobs $JOBS\"
ExecStart=
ExecStart=/usr/bin/distccd --no-detach \$DISTCC_ARGS
EOF

        echo \">>> Reloading systemd\"
        systemctl daemon-reload

        echo \">>> Re-executing systemd (required for override)\"
        systemctl daemon-reexec

        echo \">>> Restarting distccd\"
        systemctl restart distccd

        echo \">>> Checking distccd status\"
        systemctl is-active distccd || echo \"WARNING: distccd not active\"

        echo \">>> Checking port 3632\"
        ss -tnlp | grep 3632 || echo \"WARNING: distccd NOT listening on port 3632\"
    '"

    echo
done

echo "====================================================================="
echo " DISTCCD WORKER BOOTSTRAP COMPLETE"
echo "====================================================================="
