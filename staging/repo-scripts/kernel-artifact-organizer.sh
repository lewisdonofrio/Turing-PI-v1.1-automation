#!/usr/bin/env bash
#
# =====================================================================
#  /home/builder/scripts/kernel-artifact-organizer.sh
#
#  Purpose:
#    Collect and organize kernel build artifacts into a structured,
#    timestamped directory under /home/builder/artifacts/kernel/.
#    This includes zImage, dtbs, modules, System.map, and logs.
#
#  Notes:
#    - ASCII-only, nano-safe, deterministic.
#    - No tabs, no Unicode, no timestamps inside the script.
#    - Must be run as builder on kubenode1.
#    - Assumes kernel-build.sh and kernel-package.sh have completed.
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
LOGDIR="/home/builder/build-logs"
PKGOUT="/home/builder/pkgout"
ARTBASE="/home/builder/artifacts/kernel"

if [ ! -d "$SRC" ]; then
    echo "ERROR: Kernel source directory not found: $SRC"
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
#  Copy kernel image and related files
# ---------------------------------------------------------------------

echo "Copying kernel image and metadata..."

cp "$SRC/arch/arm/boot/zImage" "$ARTDIR/" 2>/dev/null || echo "zImage not found"
cp "$SRC/System.map" "$ARTDIR/" 2>/dev/null || echo "System.map not found"

# ---------------------------------------------------------------------
#  Copy dtbs
# ---------------------------------------------------------------------

if [ -d "$SRC/arch/arm/boot/dts" ]; then
    mkdir -p "$ARTDIR/dtbs"
    cp "$SRC/arch/arm/boot/dts/"*.dtb "$ARTDIR/dtbs/" 2>/dev/null || true
fi

# ---------------------------------------------------------------------
#  Copy modules
# ---------------------------------------------------------------------

if [ -d "$SRC/modules" ]; then
    mkdir -p "$ARTDIR/modules"
    cp -r "$SRC/modules" "$ARTDIR/" 2>/dev/null || true
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
