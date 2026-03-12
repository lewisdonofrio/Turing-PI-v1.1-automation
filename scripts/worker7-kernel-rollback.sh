#!/usr/bin/env bash
set -euo pipefail

BACKUP_ROOT="/var/backups/kernel"

echo "=== WORKER7 KERNEL ROLLBACK HELPER ==="
echo "Backup root: $BACKUP_ROOT"
echo

if [[ ! -d "$BACKUP_ROOT" ]]; then
    echo "ERROR: No backup directory found at $BACKUP_ROOT"
    exit 1
fi

LATEST_BACKUP=$(ls -1 "$BACKUP_ROOT" | sort | tail -n1 || true)
if [[ -z "$LATEST_BACKUP" ]]; then
    echo "ERROR: No backups found under $BACKUP_ROOT"
    exit 1
fi

BACKUP_DIR="$BACKUP_ROOT/$LATEST_BACKUP"
echo "Latest backup: $BACKUP_DIR"
echo

read -r -p "Proceed with rollback from this backup? [y/N] " ans
case "$ans" in
    y|Y|yes|YES) ;;
    *) echo "Aborting rollback."; exit 1 ;;
esac

# Restore /boot if backup exists
if [[ -d "$BACKUP_DIR/boot/boot" ]]; then
    echo "Restoring /boot from backup..."
    sudo rm -rf /boot/*
    sudo cp -a "$BACKUP_DIR/boot/boot/"* /boot/
else
    echo "WARNING: No /boot backup found in $BACKUP_DIR/boot/boot"
fi

# Restore modules directory (if present)
if [[ -d "$BACKUP_DIR/lib/modules" ]]; then
    echo "Restoring /lib/modules from backup..."
    sudo rm -rf /lib/modules/*
    sudo cp -a "$BACKUP_DIR/lib/modules/"* /lib/modules/
else
    echo "WARNING: No /lib/modules backup found in $BACKUP_DIR/lib/modules"
fi

echo
echo "=== ROLLBACK COMPLETE ==="
echo "You should reboot now to complete rollback."
