#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
    echo "Usage: $0 /path/to/worker7-kernel-<krel>.tar.gz"
    exit 1
fi

PKG_TARBALL="$1"

if [[ ! -f "$PKG_TARBALL" ]]; then
    echo "ERROR: Tarball not found: $PKG_TARBALL"
    exit 1
fi

echo "=== KERNEL DEPLOYER FOR WORKER7 ==="
echo "Tarball: $PKG_TARBALL"
echo

NOW=$(date +%Y%m%d-%H%M%S)
CURRENT_KREL=$(uname -r)

ROOT_DST="/usr/local/kernels"
BOOT_BACKUP_ROOT="/var/backups/kernel"

STAGE="$ROOT_DST/stage-$NOW"
INSTALL_ROOT="$ROOT_DST/installed"
BACKUP_DIR="$BOOT_BACKUP_ROOT/$NOW"

echo "Current running kernel: $CURRENT_KREL"
echo "Stage dir:              $STAGE"
echo "Install root:           $INSTALL_ROOT"
echo "Backup dir:             $BACKUP_DIR"
echo

sudo mkdir -p "$STAGE" "$INSTALL_ROOT" "$BACKUP_DIR"
sudo tar -C "$STAGE" -xzf "$PKG_TARBALL"

# Detect KREL from staged modules
STAGED_MOD_ROOT=$(find "$STAGE/lib/modules" -maxdepth 1 -mindepth 1 -type d | head -n1 || true)
if [[ -z "$STAGED_MOD_ROOT" ]]; then
    echo "ERROR: No modules directory found in stage."
    exit 1
fi

STAGED_KREL=$(basename "$STAGED_MOD_ROOT")
echo "Staged kernelrelease: $STAGED_KREL"
echo

# Backup current system state
echo "Backing up current /boot and /lib/modules/$CURRENT_KREL ..."
sudo mkdir -p "$BACKUP_DIR/boot" "$BACKUP_DIR/lib/modules"
if [[ -d /boot ]]; then
    sudo cp -a /boot "$BACKUP_DIR/boot/"
fi
if [[ -d "/lib/modules/$CURRENT_KREL" ]]; then
    sudo cp -a "/lib/modules/$CURRENT_KREL" "$BACKUP_DIR/lib/modules/"
fi
echo "Backup complete."
echo

# Install modules
echo "Installing modules to /lib/modules/$STAGED_KREL ..."
sudo rm -rf "/lib/modules/$STAGED_KREL"
sudo mkdir -p "/lib/modules"
sudo cp -a "$STAGED_MOD_ROOT" "/lib/modules/"
echo "Modules installed."
echo

# Install boot files under /boot/kernels/<krel> (non-destructive)
BOOT_KERNEL_DIR="/boot/kernels/$STAGED_KREL"
echo "Installing boot files to $BOOT_KERNEL_DIR ..."
sudo mkdir -p "$BOOT_KERNEL_DIR"

if [[ -d "$STAGE/boot" ]]; then
    sudo cp -av "$STAGE/boot/"* "$BOOT_KERNEL_DIR/"
fi

echo
echo "=== DEPLOYMENT COMPLETE (bootloader not yet changed) ==="
echo "New kernel files:   $BOOT_KERNEL_DIR"
echo "New modules:        /lib/modules/$STAGED_KREL"
echo "Backup location:    $BACKUP_DIR"
echo
echo "Next step: Update your bootloader/config.txt to boot from $BOOT_KERNEL_DIR if desired."
