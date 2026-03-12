#!/usr/bin/env bash
set -euo pipefail

BACKUP_DIR="$1"

echo "== Pi Kernel Rollback =="
echo "Backup dir: $BACKUP_DIR"
echo

[[ -f "$BACKUP_DIR/boot.tgz" ]] || { echo "ERROR: boot.tgz missing"; exit 1; }

echo "-- Restoring /boot..."
tar -xpf "$BACKUP_DIR/boot.tgz" -C /

MOD_BACKUP=$(ls "$BACKUP_DIR"/modules-*.tgz 2>/dev/null | head -n1 || true)
if [[ -n "$MOD_BACKUP" ]]; then
  echo "-- Restoring modules from $MOD_BACKUP..."
  tar -xpf "$MOD_BACKUP" -C /
else
  echo "WARNING: No modules backup found."
fi

echo
echo "Rollback complete. Reboot to use restored kernel."
