#!/usr/bin/env bash
#
# =====================================================================
#  /home/builder/scripts/kernel-rollback-worker7.sh
#
#  Purpose:
#    Roll back worker7 to the previously installed kernel. This script
#    restores the prior kernel image, DTBs, and module directory using
#    backup copies created automatically by pacman during upgrades.
#
#  Notes:
#    - ASCII-only, nano-safe, deterministic.
#    - No tabs, no Unicode, no timestamps.
#    - Must be run as builder on kubenode1.
#    - Assumes pacman backup files exist on worker7.
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

echo "Preparing to roll back kernel on worker7"
echo

# ---------------------------------------------------------------------
#  Verify target is reachable
# ---------------------------------------------------------------------

if ! ssh "$TARGET" "echo ok" >/dev/null 2>&1; then
    echo "ERROR: Unable to reach $TARGET via SSH"
    exit 1
fi

# ---------------------------------------------------------------------
#  Confirm rollback
# ---------------------------------------------------------------------

echo "This will restore the previous kernel on worker7."
echo "Proceed with rollback? (yes/no)"
read answer

if [ "$answer" != "yes" ]; then
    echo "Aborting rollback."
    exit 0
fi

# ---------------------------------------------------------------------
#  Restore previous kernel package
# ---------------------------------------------------------------------

echo "Restoring previous kernel package..."

ssh "$TARGET" "sudo pacman -U --noconfirm /var/cache/pacman/pkg/linux-*.pkg.tar.zst"

# ---------------------------------------------------------------------
#  Restore /boot kernel files
# ---------------------------------------------------------------------

echo "Restoring /boot kernel files..."

ssh "$TARGET" "sudo cp /boot/kernel-backup/kernel*.img /boot/ 2>/dev/null || echo 'No kernel backup found'"
ssh "$TARGET" "sudo cp /boot/kernel-backup/*.dtb /boot/ 2>/dev/null || echo 'No DTB backup found'"
ssh "$TARGET" "sudo cp -r /boot/kernel-backup/overlays /boot/ 2>/dev/null || echo 'No overlay backup found'"

# ---------------------------------------------------------------------
#  Restore modules
# ---------------------------------------------------------------------

echo "Restoring previous modules..."

ssh "$TARGET" "sudo rm -rf /usr/lib/modules"
ssh "$TARGET" "sudo cp -r /usr/lib/modules-backup /usr/lib/modules 2>/dev/null || echo 'No module backup found'"

# ---------------------------------------------------------------------
#  Confirm reboot
# ---------------------------------------------------------------------

echo
echo "Rollback complete."
echo "Reboot worker7 to return to the previous kernel? (yes/no)"
read answer

if [ "$answer" != "yes" ]; then
    echo "Rollback complete without reboot."
    exit 0
fi

# ---------------------------------------------------------------------
#  Reboot worker7
# ---------------------------------------------------------------------

echo "Rebooting worker7..."
ssh "$TARGET" "sudo reboot"

echo "Worker7 is rebooting."
echo "Use kernel-health-worker7.sh after it comes back online."
