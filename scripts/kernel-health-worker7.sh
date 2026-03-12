#!/usr/bin/env bash
#
# =====================================================================
#  /home/builder/scripts/kernel-health-worker7.sh
#
#  Purpose:
#    Perform a basic health check on worker7 after a kernel upgrade:
#    - connectivity
#    - kernel version
#    - modules tree
#    - systemd / k3s-agent
#    - dmesg sanity scan
#
#  Notes:
#    - ASCII-only, nano-safe, deterministic.
#    - Must be run as builder on kubenode1.
# =====================================================================

set -euo pipefail

TARGET="kubenode7.home.lab"

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

echo "Running kernel health check on $TARGET"
echo

# ---------------------------------------------------------------------
#  Connectivity and basic info
# ---------------------------------------------------------------------

if ! ssh "$TARGET" "echo ok" >/dev/null 2>&1; then
    echo "ERROR: Unable to reach $TARGET via SSH"
    exit 1
fi

echo "Connectivity: OK"
echo

echo "Kernel version:"
ssh "$TARGET" "uname -a"
echo

# ---------------------------------------------------------------------
#  Modules tree check
# ---------------------------------------------------------------------

echo "Checking modules directory..."

ssh "$TARGET" '
    KREL=$(uname -r)
    MODDIR="/usr/lib/modules/$KREL"
    if [ -d "$MODDIR" ]; then
        echo "Modules directory exists: $MODDIR"
        echo "Module count:"
        find "$MODDIR" -type f -name "*.ko" | wc -l
    else
        echo "WARNING: Modules directory missing: $MODDIR"
    fi
'
echo

# ---------------------------------------------------------------------
#  Systemd and k3s-agent status
# ---------------------------------------------------------------------

echo "Checking systemd and k3s-agent status..."

ssh "$TARGET" '
    if command -v systemctl >/dev/null 2>&1; then
        systemctl is-system-running || true
        systemctl status k3s-agent --no-pager -l || echo "k3s-agent status unavailable"
    else
        echo "WARNING: systemctl not available on target"
    fi
'
echo

# ---------------------------------------------------------------------
#  dmesg sanity scan
# ---------------------------------------------------------------------

echo "Scanning dmesg for kernel errors..."

ssh "$TARGET" '
    if command -v dmesg >/dev/null 2>&1; then
        dmesg | grep -Ei "panic|BUG:|Oops|call trace" || echo "No obvious kernel panics or oops messages found"
    else
        echo "WARNING: dmesg not available on target"
    fi
'
echo

echo "Kernel health check complete for $TARGET."
