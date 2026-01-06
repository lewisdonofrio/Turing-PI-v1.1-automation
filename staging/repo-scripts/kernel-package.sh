#!/usr/bin/env bash
#
# =====================================================================
#  /home/builder/scripts/kernel-package.sh
#
#  Purpose:
#    Package the compiled Linux kernel into Arch Linux packages using
#    makepkg. This script assumes the kernel has already been built
#    using kernel-build.sh and that PKGBUILDs are located in the
#    standard directory.
#
#  Notes:
#    - ASCII-only, nano-safe, deterministic.
#    - No tabs, no Unicode, no timestamps.
#    - Must be run as builder on kubenode1.
#    - Does not build the kernel; only packages it.
#    - Output packages are stored under pkgout/.
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

PKGDIR="/home/builder/PKGBUILDs/kernel"
OUTDIR="/home/builder/pkgout"

if [ ! -d "$PKGDIR" ]; then
    echo "ERROR: PKGBUILD directory not found: $PKGDIR"
    exit 1
fi

mkdir -p "$OUTDIR"

cd "$PKGDIR"

# ---------------------------------------------------------------------
#  Package build
# ---------------------------------------------------------------------

echo "Packaging kernel using makepkg..."
makepkg -sf --noconfirm

# ---------------------------------------------------------------------
#  Move artifacts to output directory
# ---------------------------------------------------------------------

echo "Moving package artifacts to $OUTDIR"
mv -v ./*.pkg.tar.zst "$OUTDIR"/

echo "Kernel packaging complete."
