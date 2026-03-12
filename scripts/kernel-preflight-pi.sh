#!/usr/bin/env bash
set -euo pipefail

#
#  kernel-preflight-pi.sh
#
#  Unified validator for:
#    1. kernel-out build correctness
#    2. Raspberry Pi deployment bundle correctness
#

OUT_DIR="$HOME/kernel-out"
SHADOW="$HOME/kernel-shadow/preflight"

echo "=============================================================="
echo "  RASPBERRY PI KERNEL PREFLIGHT (build + deploy bundle)"
echo "=============================================================="
echo "OUT_DIR:   $OUT_DIR"
echo "SHADOW:    $SHADOW"
echo

# ---------------------------------------------------------------
# STEP 1: Validate kernel-out (your existing validator)
# ---------------------------------------------------------------

echo "-- Validating kernel-out build artifacts..."

if [[ ! -f "$OUT_DIR/include/config/kernel.release" ]]; then
    echo "ERROR: kernel.release not found in OUT_DIR"
    exit 1
fi

KREL=$(cat "$OUT_DIR/include/config/kernel.release")
MODDIR="$OUT_DIR/lib/modules/$KREL"

echo "Detected kernelrelease: $KREL"
echo "Modules directory:      $MODDIR"
echo

REQUIRED_FILES=(
    "$OUT_DIR/vmlinux"
    "$OUT_DIR/System.map"
    "$OUT_DIR/.config"
    "$OUT_DIR/Module.symvers"
    "$OUT_DIR/modules.builtin"
    "$OUT_DIR/modules.builtin.modinfo"
    "$OUT_DIR/arch/arm/boot/Image"
    "$OUT_DIR/arch/arm/boot/zImage"
)

echo "-- Checking required artifacts..."
for f in "${REQUIRED_FILES[@]}"; do
    [[ -f "$f" ]] || { echo "ERROR: Missing $f"; exit 1; }
done
echo "Build artifacts OK."
echo

echo "-- Checking DTBs..."
DTB_DIR="$OUT_DIR/arch/arm/boot/dts"
BROADCOM_DIR="$DTB_DIR/broadcom"

if compgen -G "$DTB_DIR/*.dtb" > /dev/null; then
    DTB_COUNT=$(ls "$DTB_DIR"/*.dtb | wc -l)
elif compgen -G "$BROADCOM_DIR/*.dtb" > /dev/null; then
    DTB_COUNT=$(ls "$BROADCOM_DIR"/*.dtb | wc -l)
else
    echo "ERROR: No DTBs found"
    exit 1
fi
echo "Found $DTB_COUNT DTBs."
echo

echo "-- Checking overlays..."
OVERLAY_DIR="$DTB_DIR/overlays"
[[ -d "$OVERLAY_DIR" ]] || { echo "ERROR: overlays missing"; exit 1; }
OVERLAY_COUNT=$(ls "$OVERLAY_DIR"/*.dtbo | wc -l)
echo "Found $OVERLAY_COUNT overlays."
echo

echo "-- Checking modules..."
[[ -d "$MODDIR" ]] || { echo "ERROR: modules dir missing"; exit 1; }
KO_COUNT=$(find "$MODDIR" -type f -name "*.ko.xz" | wc -l)
[[ "$KO_COUNT" -gt 0 ]] || { echo "ERROR: no modules"; exit 1; }
echo "Found $KO_COUNT modules."
echo

echo "-- Checking module metadata..."
META_FILES=(
    "$MODDIR/modules.dep"
    "$MODDIR/modules.alias"
    "$MODDIR/modules.order"
)
for f in "${META_FILES[@]}"; do
    [[ -f "$f" ]] || { echo "ERROR: missing $f"; exit 1; }
done
echo "Module metadata OK."
echo

echo "-- Checking build symlink..."
[[ -L "$MODDIR/build" ]] || { echo "ERROR: build symlink missing"; exit 1; }
TARGET=$(readlink -f "$MODDIR/build")
[[ "$TARGET" == "$OUT_DIR" ]] || { echo "ERROR: build symlink wrong"; exit 1; }
echo "Build symlink OK."
echo

# ---------------------------------------------------------------
# STEP 2: Validate Raspberry Pi deployment bundle (shadow-root)
# ---------------------------------------------------------------

echo "-- Preparing shadow-root..."
rm -rf "$SHADOW"
mkdir -p "$SHADOW"

echo "-- Creating deployment bundle into shadow-root..."
# You will replace this with your actual bundling logic
# For now we assume you rsync or copy kernel-out into SHADOW
rsync -a "$OUT_DIR/" "$SHADOW/"

echo "-- Checking forbidden paths..."
FORBIDDEN=$(find "$SHADOW" -maxdepth 3 -type d | grep -E "/(usr|bin|sbin|lib/[^m]|etc|opt|var)")
if [[ -n "$FORBIDDEN" ]]; then
    echo "ERROR: Deployment bundle contains forbidden system paths:"
    echo "$FORBIDDEN"
    exit 1
fi
echo "No forbidden paths."
echo

echo "-- Checking kernel image naming..."
KIMG=$(find "$SHADOW/boot" -maxdepth 1 -name "kernel*.img" | head -n1)
[[ -n "$KIMG" ]] || { echo "ERROR: no kernel image"; exit 1; }
echo "Kernel image: $KIMG"
echo

echo "-- Extracting kernelrelease from image..."
IMG_KREL=$(strings "$KIMG" | grep -E "^[0-9]+\.[0-9]+\.[0-9]+" | head -n1)
[[ -n "$IMG_KREL" ]] || { echo "ERROR: cannot extract kernelrelease"; exit 1; }
echo "Image kernelrelease: $IMG_KREL"
echo

echo "-- Ensuring modules directory matches kernelrelease..."
[[ -d "$SHADOW/lib/modules/$IMG_KREL" ]] || {
    echo "ERROR: modules directory does not match kernelrelease:"
    echo "Expected: lib/modules/$IMG_KREL"
    exit 1
}
echo "Modules directory matches kernelrelease."
echo

echo "-- Checking DTBs in shadow-root..."
DTB_COUNT2=$(find "$SHADOW/boot" -maxdepth 1 -name "*.dtb" | wc -l)
[[ "$DTB_COUNT2" -gt 0 ]] || { echo "ERROR: no DTBs in shadow-root"; exit 1; }
echo "Found $DTB_COUNT2 DTBs."
echo

echo "-- Checking overlays in shadow-root..."
[[ -d "$SHADOW/boot/overlays" ]] || { echo "ERROR: overlays missing"; exit 1; }
echo "Overlays OK."
echo

echo "=============================================================="
echo "  PREFLIGHT SUCCESS — build + Pi bundle are valid"
echo "=============================================================="
exit 0
