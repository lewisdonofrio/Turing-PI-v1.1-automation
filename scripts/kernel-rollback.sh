#!/usr/bin/env bash
set -euo pipefail

# ==============================================================
#  UNIVERSAL RASPBERRY PI KERNEL ROLLBACK
#  Restores the last backup created by kernel-deploy.sh.
#  Works on all nodes with identical filesystem layout.
# ==============================================================

BACKUP_ROOT="/"
BACKUP_PATTERN="/boot-backup-*"

echo "=== UNIVERSAL KERNEL ROLLBACK ==="
echo

# --------------------------------------------------------------
# Locate the most recent backup directory
# --------------------------------------------------------------
LATEST_BACKUP=$(ls -1dt $BACKUP_PATTERN 2>/dev/null | head -n1 || true)

if [[ -z "$LATEST_BACKUP" ]]; then
    echo "ERROR: No backup directories found matching: $BACKUP_PATTERN"
    exit 1
fi

echo "Found backup: $LATEST_BACKUP"
echo

# --------------------------------------------------------------
# Confirm structure
# --------------------------------------------------------------
if [[ ! -d "$LATEST_BACKUP/boot" ]]; then
    echo "ERROR: Backup missing /boot directory"
    exit 1
fi

MODULE_BACKUP=$(ls -1d "$LATEST_BACKUP"/modules-* 2>/dev/null | head -n1 || true)

if [[ -z "$MODULE_BACKUP" ]]; then
    echo "ERROR: Backup missing modules-* directory"
    exit 1
fi

echo "Modules backup: $MODULE_BACKUP"
echo

# --------------------------------------------------------------
# Restore /boot
# --------------------------------------------------------------
echo "Restoring /boot..."
sudo rm -rf /boot/*
sudo cp -a "$LATEST_BACKUP/boot/"* /boot/

# --------------------------------------------------------------
# Restore modules
# --------------------------------------------------------------
RESTORE_KERNEL=$(basename "$MODULE_BACKUP" | sed 's/modules-//')

echo "Restoring modules for kernel: $RESTORE_KERNEL"
sudo rm -rf "/lib/modules/$RESTORE_KERNEL" || true
sudo cp -a "$MODULE_BACKUP" "/lib/modules/$RESTORE_KERNEL"

# --------------------------------------------------------------
# Done
# --------------------------------------------------------------
echo
echo "=== ROLLBACK COMPLETE ==="
echo "Restored kernel: $RESTORE_KERNEL"
echo "Backup used: $LATEST_BACKUP"
echo "Reboot to activate rollback."

