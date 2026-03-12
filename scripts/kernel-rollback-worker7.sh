#!/usr/bin/env bash
#
# =====================================================================
#  /home/builder/scripts/kernel-rollback-worker7.sh
#
#  Purpose:
#    Roll back worker7 to a previously backed-up kernel state:
#    - Restore /boot
#    - Restore /usr/lib/modules
#    - Reboot worker7
#
#  Notes:
#    - ASCII-only, nano-safe, deterministic.
#    - Must be run as builder on kubenode1.
# =====================================================================

set -euo pipefail

TARGET="kubenode7.home.lab"
BACKUP_GLOB="/var/backups/kernel-*"

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

if ! ssh "$TARGET" "echo ok" >/dev/null 2>&1; then
    echo "ERROR: Unable to reach $TARGET via SSH"
    exit 1
fi

# ---------------------------------------------------------------------
#  Select backup
# ---------------------------------------------------------------------

echo "Available kernel backups on worker7 host (local fs):"
ls -1d $BACKUP_GLOB 2>/dev/null | sort || echo "No backups found."

LAST_BACKUP=$(ls -1d $BACKUP_GLOB 2>/dev/null | sort | tail -n 1 || true)

if [ -z "$LAST_BACKUP" ]; then
    echo "ERROR: No kernel backups found under /var/backups."
    exit 1
fi

echo
echo "Most recent backup will be used for rollback:"
echo "  $LAST_BACKUP"
echo
echo "Proceed with rollback to this backup? This will overwrite /boot and /usr/lib/modules on $TARGET. (yes/no)"
read answer

if [ "$answer" != "yes" ]; then
    echo "Aborting rollback."
    exit 0
fi

# ---------------------------------------------------------------------
#  Perform rollback
# ---------------------------------------------------------------------

echo
echo "Restoring /boot from backup..."
ssh "$TARGET" "sudo rsync -a \"$LAST_BACKUP/boot/\" /boot/"

echo
echo "Restoring /usr/lib/modules from backup..."
ssh "$TARGET" "sudo rsync -a \"$LAST_BACKUP/modules/\" /usr/lib/modules/"

echo
echo "Rollback complete. Reboot worker7 to apply the restored kernel? (yes/no)"
read reboot_answer

if [ "$reboot_answer" != "yes" ]; then
    echo "Rollback performed, but reboot skipped."
    exit 0
fi

echo "Rebooting $TARGET..."
ssh "$TARGET" "sudo reboot"

echo "Worker7 is rebooting with restored kernel."
