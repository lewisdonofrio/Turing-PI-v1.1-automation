#!/usr/bin/env bash
#
# =====================================================================
#  /home/builder/scripts/kernel-health-worker7.sh
#
#  Purpose:
#    Verify that worker7 successfully booted into the newly installed
#    kernel. This script checks kernel version, module availability,
#    DTB presence, dmesg for critical errors, and optional k3s status.
#
#  Notes:
#    - ASCII-only, nano-safe, deterministic.
#    - No tabs, no Unicode, no timestamps.
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

echo "Checking health of worker7 after kernel reboot..."
echo

# ---------------------------------------------------------------------
#  Wait for SSH to return
# ---------------------------------------------------------------------

echo "Waiting for SSH to become available..."

for i in $(seq 1 30); do
    if ssh "$TARGET" "echo ok" >/dev/null 2>&1; then
        echo "SSH is up."
        break
    fi
    sleep 2
done

# ---------------------------------------------------------------------
#  Kernel version check
# ---------------------------------------------------------------------

echo
echo "Kernel version:"
ssh "$TARGET" "uname -a"

# ---------------------------------------------------------------------
#  Module directory check
# ---------------------------------------------------------------------

echo
echo "Checking module directory..."

ssh "$TARGET" "ls -1 /usr/lib/modules" || echo "WARNING: modules directory missing"

# ---------------------------------------------------------------------
#  DTB presence check
# ---------------------------------------------------------------------

echo
echo "Checking DTBs in /boot..."

ssh "$TARGET" "ls -1 /boot/*.dtb 2>/dev/null" || echo "WARNING: DTBs missing"

# ---------------------------------------------------------------------
#  dmesg scan for critical errors
# ---------------------------------------------------------------------

echo
echo "Scanning dmesg for critical errors..."

ssh "$TARGET" "dmesg | grep -i 'error\|fail\|panic' || echo 'No critical errors found'"

# ---------------------------------------------------------------------
#  Optional: k3s status
# ---------------------------------------------------------------------

echo
echo "Checking k3s status (if installed)..."

ssh "$TARGET" "systemctl is-active k3s 2>/dev/null || echo 'k3s not running or not installed'"

# ---------------------------------------------------------------------
#  Summary
# ---------------------------------------------------------------------

echo
echo "Health check complete."
echo "If all sections above look correct, worker7 successfully booted the new kernel."
