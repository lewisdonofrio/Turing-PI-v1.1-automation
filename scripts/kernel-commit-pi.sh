#!/usr/bin/env bash
set -euo pipefail

SHADOW="$1"
BACKUP_ROOT="/srv/kernel-backups"
STAMP=$(date +%Y%m%d-%H%M%S)
BACKUP_DIR="$BACKUP_ROOT/$STAMP"

echo "== Pi Kernel Commit =="
echo "Shadow-root: $SHADOW"
echo "Backup dir:  $BACKUP_DIR"
echo

[[ -d "$SHADOW/boot" && -d "$SHADOW/lib/modules" ]] || {
  echo "ERROR: Shadow-root missing boot/ or lib/modules/"
  exit 1
}

mkdir -p "$BACKUP_DIR"

echo "-- Backing up current /boot and modules..."
tar -cpzf "$BACKUP_DIR/boot.tgz" /boot
tar -cpzf "$BACKUP_DIR/modules-$(uname -r).tgz" /lib/modules/$(uname -r)

echo "-- Applying /boot from shadow-root..."
rsync -av --itemize-changes "$SHADOW/boot/" /boot/

echo "-- Applying modules from shadow-root..."
rsync -av --itemize-changes "$SHADOW/lib/modules/" /lib/modules/

echo
echo "Commit complete."
echo "Backup stored at: $BACKUP_DIR"
echo "Now update /boot/config.txt to point to the new kernel image if needed, then reboot."
