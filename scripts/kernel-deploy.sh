#!/usr/bin/env bash
set -euo pipefail

# ==============================================================
#  UNIVERSAL RASPBERRY PI KERNEL DEPLOYER
#  Works on all nodes with identical filesystem layout.
#  Deploys a kernel package produced by your packager script.
# ==============================================================

if [[ $# -ne 1 ]]; then
    echo "Usage: $0 <kernel-tarball>"
    exit 1
fi

TARBALL="$1"

if [[ ! -f "$TARBALL" ]]; then
    echo "ERROR: Tarball not found: $TARBALL"
    exit 1
fi

echo "=== UNIVERSAL KERNEL DEPLOYER ==="
echo "Tarball: $TARBALL"
echo

# --------------------------------------------------------------
# Create staging directory
# --------------------------------------------------------------
STAGING="/tmp/kernel-deploy-$(date +%s)"
mkdir -p "$STAGING"

echo "Unpacking tarball..."
tar -xzf "$TARBALL" -C "$STAGING"

# Expecting:
#   $STAGING/boot/zImage-<ver>
#   $STAGING/boot/dtbs/...
#   $STAGING/boot/overlays/...
#   $STAGING/lib/modules/<ver>/
# --------------------------------------------------------------

# --------------------------------------------------------------
# Detect kernel version inside package
# --------------------------------------------------------------
PKG_KERNEL=$(basename "$STAGING/lib/modules"/*)
echo "Package kernel version: $PKG_KERNEL"

# --------------------------------------------------------------
# Detect running kernel version
# --------------------------------------------------------------
RUNNING_KERNEL=$(uname -r)
echo "Running kernel version: $RUNNING_KERNEL"
echo

# --------------------------------------------------------------
# Backup current boot + modules
# --------------------------------------------------------------
BACKUP_DIR="/boot-backup-$(date +%Y%m%d-%H%M%S)"
echo "Creating backup at: $BACKUP_DIR"

sudo mkdir -p "$BACKUP_DIR"
sudo cp -a /boot "$BACKUP_DIR/boot"
sudo cp -a "/lib/modules/$RUNNING_KERNEL" "$BACKUP_DIR/modules-$RUNNING_KERNEL"

echo "Backup complete."
echo

# --------------------------------------------------------------
# Install modules
# --------------------------------------------------------------
echo "Installing modules..."
sudo cp -a "$STAGING/lib/modules/$PKG_KERNEL" /lib/modules/

# --------------------------------------------------------------
# Install kernel image (replace kernel7.img)
# --------------------------------------------------------------
echo "Installing kernel image..."
PKG_ZIMAGE=$(ls "$STAGING/boot"/zImage-* | head -n1)
sudo cp "$PKG_ZIMAGE" /boot/kernel7.img

# --------------------------------------------------------------
# Install DTBs (copy into /boot)
# --------------------------------------------------------------
echo "Installing DTBs..."
sudo rsync -a "$STAGING/boot/dtbs/broadcom/" /boot/

# --------------------------------------------------------------
# Install overlays
# --------------------------------------------------------------
echo "Installing overlays..."
sudo rsync -a "$STAGING/boot/overlays/" /boot/overlays/

# --------------------------------------------------------------
# Ensure correct DTB selection (CM3/CM3+ IO3)
# --------------------------------------------------------------
CM3_DTB="bcm2837-rpi-cm3-io3.dtb"

if [[ -f "/boot/$CM3_DTB" ]]; then
    echo "Ensuring config.txt references correct DTB..."
    if ! grep -q "^device_tree=" /boot/config.txt; then
        echo "device_tree=$CM3_DTB" | sudo tee -a /boot/config.txt >/dev/null
    fi
fi

echo
echo "=== DEPLOY COMPLETE ==="
echo "Installed kernel: $PKG_KERNEL"
echo "Backup directory: $BACKUP_DIR"
echo "Ready for reboot."

