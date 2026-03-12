#!/usr/bin/env bash
set -euo pipefail

OUT_DIR="$HOME/kernel-out"

echo "=============================================================="
echo "  RASPBERRY PI KERNEL PREFLIGHT — BUILD VALIDATION"
echo "=============================================================="
echo "OUT_DIR:   $OUT_DIR"
echo

# ---------------------------------------------------------------
# STEP 1: Detect kernelrelease
# ---------------------------------------------------------------
if [[ ! -f "$OUT_DIR/include/config/kernel.release" ]]; then
    echo "ERROR: kernel.release not found in OUT_DIR"
    exit 1
fi

KREL=$(cat "$OUT_DIR/include/config/kernel.release")
MODDIR="$OUT_DIR/lib/modules/$KREL"

echo "Detected kernelrelease: $KREL"
echo "Modules directory:      $MODDIR"
echo

# ---------------------------------------------------------------
# STEP 2: Required top-level artifacts
# ---------------------------------------------------------------
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

echo "Checking required artifacts..."
for f in "${REQUIRED_FILES[@]}"; do
    [[ -f "$f" ]] || { echo "ERROR: Missing required artifact: $f"; exit 1; }
done
echo "All required artifacts present."
echo

# ---------------------------------------------------------------
# STEP 3: Validate DTBs
# ---------------------------------------------------------------
DTB_DIR="$OUT_DIR/arch/arm/boot/dts"
BROADCOM_DIR="$DTB_DIR/broadcom"

echo "Checking DTBs..."

if compgen -G "$DTB_DIR/*.dtb" > /dev/null; then
    DTB_COUNT=$(ls "$DTB_DIR"/*.dtb | wc -l)
elif compgen -G "$BROADCOM_DIR/*.dtb" > /dev/null; then
    DTB_COUNT=$(ls "$BROADCOM_DIR"/*.dtb | wc -l)
else
    echo "ERROR: No DTB files found in expected locations."
    exit 1
fi

echo "Found $DTB_COUNT DTB files."
echo

# ---------------------------------------------------------------
# STEP 4: Validate overlays
# ---------------------------------------------------------------
OVERLAY_DIR="$DTB_DIR/overlays"

echo "Checking overlays..."

[[ -d "$OVERLAY_DIR" ]] || { echo "ERROR: overlays directory missing: $OVERLAY_DIR"; exit 1; }

OVERLAY_COUNT=$(ls "$OVERLAY_DIR"/*.dtbo | wc -l)
echo "Found $OVERLAY_COUNT overlay files."
echo

# ---------------------------------------------------------------
# STEP 5: Validate modules
# ---------------------------------------------------------------
echo "Checking modules..."

[[ -d "$MODDIR" ]] || { echo "ERROR: modules directory missing: $MODDIR"; exit 1; }

KO_COUNT=$(find "$MODDIR" -type f -name "*.ko.xz" | wc -l)
[[ "$KO_COUNT" -gt 0 ]] || { echo "ERROR: No .ko.xz modules found in $MODDIR"; exit 1; }

echo "Found $KO_COUNT kernel modules."
echo

# ---------------------------------------------------------------
# STEP 6: Validate module metadata
# ---------------------------------------------------------------
META_FILES=(
    "$MODDIR/modules.dep"
    "$MODDIR/modules.alias"
    "$MODDIR/modules.order"
)

echo "Checking module metadata..."
for f in "${META_FILES[@]}"; do
    [[ -f "$f" ]] || { echo "ERROR: Missing module metadata: $f"; exit 1; }
done
echo "Module metadata OK."
echo

# ---------------------------------------------------------------
# STEP 7: Validate build symlink
# ---------------------------------------------------------------
echo "Checking build symlink..."

[[ -L "$MODDIR/build" ]] || { echo "ERROR: build symlink missing in $MODDIR"; exit 1; }

TARGET=$(readlink -f "$MODDIR/build")
[[ "$TARGET" == "$OUT_DIR" ]] || {
    echo "ERROR: build symlink points to wrong location:"
    echo "       $TARGET"
    exit 1
}

echo "Build symlink OK."
echo

echo "=============================================================="
echo "  BUILD PREFLIGHT SUCCESS — kernel-out is valid"
echo "=============================================================="
exit 0
