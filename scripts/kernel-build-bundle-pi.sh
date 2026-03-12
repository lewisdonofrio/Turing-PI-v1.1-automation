#!/usr/bin/env bash
set -euo pipefail

OUT_DIR="/home/builder/kernel-out"
BUNDLE_ROOT="/home/builder/kernel-bundles"
KREL_FILE="$OUT_DIR/include/config/kernel.release"

[[ -f "$KREL_FILE" ]] || { echo "ERROR: $KREL_FILE missing"; exit 1; }

KREL=$(cat "$KREL_FILE")
STAMP=$(date +%Y%m%d-%H%M%S)
BUNDLE_DIR="$BUNDLE_ROOT/$KREL-$STAMP"
TARBALL="$BUNDLE_ROOT/kernel-$KREL-$STAMP.tar"

echo "== Building Pi bundle =="
echo "OUT_DIR:    $OUT_DIR"
echo "KREL:       $KREL"
echo "BUNDLE_DIR: $BUNDLE_DIR"
echo "TARBALL:    $TARBALL"
echo

rm -rf "$BUNDLE_DIR"
mkdir -p "$BUNDLE_DIR/boot" "$BUNDLE_DIR/lib/modules"

echo "-- Copying kernel image(s)..."
cp "$OUT_DIR/arch/arm/boot/zImage" "$BUNDLE_DIR/boot/kernel7-$KREL.img"

echo "-- Copying DTBs..."
DTB_SRC="$OUT_DIR/arch/arm/boot/dts"
cp "$DTB_SRC"/*.dtb "$BUNDLE_DIR/boot/" 2>/dev/null || true
cp "$DTB_SRC"/broadcom/*.dtb "$BUNDLE_DIR/boot/" 2>/dev/null || true

echo "-- Copying overlays..."
mkdir -p "$BUNDLE_DIR/boot/overlays"
cp "$DTB_SRC/overlays/"*.dtbo "$BUNDLE_DIR/boot/overlays/"

echo "-- Copying modules..."
cp -a "$OUT_DIR/lib/modules/$KREL" "$BUNDLE_DIR/lib/modules/"

echo "-- Creating tarball..."
tar -cpf "$TARBALL" -C "$BUNDLE_DIR" .

echo
echo "Bundle directory: $BUNDLE_DIR"
echo "Tarball:          $TARBALL"
echo "Done."
