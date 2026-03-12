#!/usr/bin/env bash
set -euo pipefail

# ==============================================================
#  KERNEL PACKAGER FOR WORKER7
#  Deterministic, out-of-tree safe, nano-safe, ASCII-only.
# ==============================================================

SRC_DIR="/home/builder/src/kernel"
OUT_DIR="/home/builder/kernel-out"
PKG_DIR="/home/builder/kernel-packages"
STAGING_DIR="$PKG_DIR/worker7-$(date +%s)"

mkdir -p "$PKG_DIR"
mkdir -p "$STAGING_DIR"

echo "=== KERNEL PACKAGER FOR WORKER7 ==="
echo "Source dir:  $SRC_DIR"
echo "Out dir:     $OUT_DIR"
echo "Staging dir: $STAGING_DIR"
echo

# --------------------------------------------------------------
# Extract kernelrelease from OUT_DIR (out-of-tree build)
# --------------------------------------------------------------
KERNELRELEASE_FILE="$OUT_DIR/include/config/kernel.release"

if [[ ! -f "$KERNELRELEASE_FILE" ]]; then
    echo "ERROR: kernel.release not found at:"
    echo "  $KERNELRELEASE_FILE"
    exit 1
fi

KERNELRELEASE=$(cat "$KERNELRELEASE_FILE")
echo "Detected kernelrelease: $KERNELRELEASE"
echo

# --------------------------------------------------------------
# Create directory structure inside staging
# --------------------------------------------------------------
mkdir -p "$STAGING_DIR/boot"
mkdir -p "$STAGING_DIR/boot/dtbs"
mkdir -p "$STAGING_DIR/boot/overlays"
mkdir -p "$STAGING_DIR/lib/modules"

# --------------------------------------------------------------
# Copy kernel image
# --------------------------------------------------------------
echo "Copying kernel image..."
cp "$OUT_DIR/arch/arm/boot/zImage" "$STAGING_DIR/boot/zImage-$KERNELRELEASE"

# --------------------------------------------------------------
# Copy DTBs (dot-copy ensures all contents are copied)
# --------------------------------------------------------------
echo "Copying DTBs..."
cp -r "$OUT_DIR/arch/arm/boot/dts/." "$STAGING_DIR/boot/dtbs/"

# Normalize kernel image for Raspberry Pi bootloader
# Mainline ARMv7 builds produce zImage, but the Pi bootloader expects kernel7.img.
# We normalize the name so deploy + verifier remain deterministic.

if [[ -f "$STAGING_DIR/boot/zImage-$KERNELRELEASE" ]]; then
    echo "Normalizing kernel image: zImage-$KERNELRELEASE to kernel7.img"
    cp "$STAGING_DIR/boot/zImage-$KERNELRELEASE" "$STAGING_DIR/boot/kernel7.img"
else
    echo "ERROR: Expected kernel image not found: $STAGING_DIR/boot/zImage-$KERNELRELEASE"
    exit 1
fi

# --------------------------------------------------------------
# Copy overlays (dot-copy ensures all contents are copied)
# --------------------------------------------------------------
echo "Copying overlays..."
cp -r "$OUT_DIR/arch/arm/boot/dts/overlays/." "$STAGING_DIR/boot/overlays/"

# --------------------------------------------------------------
# Copy modules
# --------------------------------------------------------------
echo "Copying modules..."
cp -r "$OUT_DIR/lib/modules/$KERNELRELEASE" "$STAGING_DIR/lib/modules/"

# --------------------------------------------------------------
# Write kernelrelease.txt
# --------------------------------------------------------------
echo "Writing kernelrelease.txt..."
echo "$KERNELRELEASE" > "$STAGING_DIR/kernelrelease.txt"

# --------------------------------------------------------------
# Create tarball
# --------------------------------------------------------------
OUT_TARBALL="$PKG_DIR/worker7-kernel-$KERNELRELEASE.tar.gz"

echo
echo "Creating tarball: $OUT_TARBALL"
tar -czf "$OUT_TARBALL" -C "$STAGING_DIR" .

echo
echo "=== PACKAGING COMPLETE ==="
echo "Staging dir: $STAGING_DIR"
echo "Tarball:     $OUT_TARBALL"

