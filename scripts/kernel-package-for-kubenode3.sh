#!/usr/bin/env bash
set -euo pipefail

# ==============================================================
#  KERNEL PACKAGER FOR WORKER3 (Pi-aware, CM3+)
# ==============================================================

SRC_DIR="/home/builder/src/kernel"
OUT_DIR="/home/builder/kernel-out"
PKG_DIR="/home/builder/kernel-packages"
STAGING_DIR="$PKG_DIR/worker3-$(date +%s)"

mkdir -p "$PKG_DIR"
mkdir -p "$STAGING_DIR"

echo "=== KERNEL PACKAGER FOR WORKER3 ==="
echo "Source dir:  $SRC_DIR"
echo "Out dir:     $OUT_DIR"
echo "Staging dir: $STAGING_DIR"
echo

# --------------------------------------------------------------
# Extract kernelrelease
# --------------------------------------------------------------
KERNELRELEASE_FILE="$OUT_DIR/include/config/kernel.release"

if [[ ! -f "$KERNELRELEASE_FILE" ]]; then
    echo "ERROR: kernel.release not found:"
    echo "  $KERNELRELEASE_FILE"
    exit 1
fi

KREL=$(cat "$KERNELRELEASE_FILE")
echo "Detected kernelrelease: $KREL"
echo

# --------------------------------------------------------------
# Create staging layout
# --------------------------------------------------------------
mkdir -p "$STAGING_DIR/boot"
mkdir -p "$STAGING_DIR/boot/overlays"
mkdir -p "$STAGING_DIR/lib/modules"

# --------------------------------------------------------------
# Copy kernel image
# --------------------------------------------------------------
echo "Copying kernel image..."
cp "$OUT_DIR/arch/arm/boot/zImage" \
   "$STAGING_DIR/boot/kernel7.img"

# --------------------------------------------------------------
# Copy DTBs (from broadcom vendor dir)
# --------------------------------------------------------------
echo "Copying DTBs..."
cp "$OUT_DIR/arch/arm/boot/dts/broadcom/"*.dtb \
   "$STAGING_DIR/boot/"

# --------------------------------------------------------------
# Copy overlays
# --------------------------------------------------------------
echo "Copying overlays..."
cp -r "$OUT_DIR/arch/arm/boot/dts/overlays/." \
      "$STAGING_DIR/boot/overlays/"

# --------------------------------------------------------------
# Copy modules
# --------------------------------------------------------------
echo "Copying modules..."
cp -r "$OUT_DIR/lib/modules/$KREL" \
      "$STAGING_DIR/lib/modules/"

# --------------------------------------------------------------
# Write kernelrelease.txt
# --------------------------------------------------------------
echo "Writing kernelrelease.txt..."
echo "$KREL" > "$STAGING_DIR/kernelrelease.txt"

# --------------------------------------------------------------
# Create tarball
# --------------------------------------------------------------
OUT_TARBALL="$PKG_DIR/worker3-kernel-$KREL.tar.gz"

echo
echo "Creating tarball: $OUT_TARBALL"
tar -czf "$OUT_TARBALL" -C "$STAGING_DIR" .

echo
echo "=== PACKAGING COMPLETE ==="
echo "Staging dir: $STAGING_DIR"
echo "Tarball:     $OUT_TARBALL"
