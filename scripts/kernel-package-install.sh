#!/usr/bin/env bash
set -euo pipefail

PKG="$1"

if [[ -z "$PKG" ]]; then
    echo "Usage: $0 <kernel-package.pkg.tar.xz>"
    exit 1
fi

if [[ ! -f "$PKG" ]]; then
    echo "ERROR: package not found: $PKG"
    exit 1
fi

TS="$(date +%Y%m%d-%H%M%S)"
BACKUP="/home/builder/backups/kpkg-$TS"

echo "Backup directory: $BACKUP"
mkdir -p "$BACKUP"

echo "Backing up /boot"
cp -a /boot "$BACKUP/boot"

echo "Backing up /usr/lib/modules"
cp -a /usr/lib/modules "$BACKUP/modules"

echo "Installing package: $PKG"
sudo pacman -U --noconfirm "$PKG"

echo "Verifying install..."
if [[ ! -d /boot || ! -d /usr/lib/modules ]]; then
    echo "ERROR: post-install verification failed"
    exit 1
fi

echo "Install complete. Reboot when ready."
