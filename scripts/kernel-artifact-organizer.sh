#!/usr/bin/env bash
#
# =====================================================================
#  /home/builder/scripts/kernel-artifact-organizer.sh
#
#  Purpose:
#    Collect and organize all kernel build artifacts into a structured,
#    timestamped directory under /home/builder/artifacts/kernel/.
#    This includes zImage, Image, vmlinux, dtbs, overlays, modules,
#    System.map, .config, Module.symvers, and logs.
#
#  Notes:
#    - ASCII-only, nano-safe, deterministic.
#    - Must be run as builder on kubenode1.
#    - Assumes kernel-build.sh and modules_install have completed.
# =====================================================================

set -euo pipefail

# ---------------------------------------------------------------------
#  Environment validation
# ---------------------------------------------------------------------

if [ "$(whoami)" != "builder" ]; then
    echo "ERROR: Must run as builder user"
    exit 1
fi

if [ "$(hostname)" != "kubenode1" ]; then
    echo "ERROR: Must run on kubenode1"
    exit 1
fi

SRC="/home/builder/src/kernel"
STAGE="/home/builder/kernel-out"
LOGDIR="/home/builder/build-logs"
PKGOUT="/home/builder/pkgout"
ARTBASE="/home/builder/artifacts/kernel"

if [ ! -d "$SRC" ]; then
    echo "ERROR: Kernel source directory not found: $SRC"
    exit 1
fi

if [ ! -d "$STAGE" ]; then
    echo "ERROR: Staging directory not found: $STAGE"
    exit 1
fi

mkdir -p "$ARTBASE"

# ---------------------------------------------------------------------
#  Create timestamped artifact directory
# ---------------------------------------------------------------------

STAMP=$(date +"%Y%m%d-%H%M%S")
ARTDIR="$ARTBASE/$STAMP"

mkdir -p "$ARTDIR"

echo "Creating artifact directory: $ARTDIR"

# ---------------------------------------------------------------------
#  Copy kernel images and metadata
# ---------------------------------------------------------------------

echo "Copying kernel images and metadata..."

cp "$SRC/arch/arm/boot/zImage" "$ARTDIR/" 2>/dev/null || echo "zImage not found"
cp "$SRC/arch/arm/boot/Image" "$ARTDIR/" 2>/dev/null || echo "Image not found"
cp "$SRC/vmlinux" "$ARTDIR/" 2>/dev/null || echo "vmlinux not found"
cp "$SRC/System.map" "$ARTDIR/" 2>/dev/null || echo "System.map not found"
cp "$SRC/.config" "$ARTDIR/" 2>/dev/null || echo ".config not found"
cp "$SRC/Module.symvers" "$ARTDIR/" 2>/dev/null || echo "Module.symvers not found"
cp "$SRC/modules.builtin" "$ARTDIR/" 2>/dev/null || echo "modules.builtin not found"
cp "$SRC/modules.builtin.modinfo" "$ARTDIR/" 2>/dev/null || echo "modules.builtin.modinfo not found"

# ---------------------------------------------------------------------
#  Copy dtbs and overlays
# ---------------------------------------------------------------------

if [ -d "$SRC/arch/arm/boot/dts" ]; then
    mkdir -p "$ARTDIR/dtbs"
    cp "$SRC/arch/arm/boot/dts/"*.dtb "$ARTDIR/dtbs/" 2>/dev/null || true

    if [ -d "$SRC/arch/arm/boot/dts/overlays" ]; then
        mkdir -p "$ARTDIR/dtbs/overlays"
        cp "$SRC/arch/arm/boot/dts/overlays/"*.dtbo "$ARTDIR/dtbs/overlays/" 2>/dev/null || true
    fi
fi

# ---------------------------------------------------------------------
#  Copy modules from staging directory
# ---------------------------------------------------------------------

MODDIR="$STAGE/lib/modules"

if [ -d "$MODDIR" ]; then
    mkdir -p "$ARTDIR/modules"
    cp -r "$MODDIR" "$ARTDIR/modules/" 2>/dev/null || true
else
    echo "WARNING: No modules found in staging directory"
fi

# ---------------------------------------------------------------------
#  Copy build logs
# ---------------------------------------------------------------------

if [ -d "$LOGDIR" ]; then
    mkdir -p "$ARTDIR/logs"
    cp "$LOGDIR"/*.log "$ARTDIR/logs/" 2>/dev/null || true
fi

# ---------------------------------------------------------------------
#  Copy packaged kernel artifacts
# ---------------------------------------------------------------------

if [ -d "$PKGOUT" ]; then
    mkdir -p "$ARTDIR/packages"
    cp "$PKGOUT"/*.pkg.tar.zst "$ARTDIR/packages/" 2>/dev/null || true
fi

echo "Artifact organization complete."
echo "Artifacts stored in: $ARTDIR"
