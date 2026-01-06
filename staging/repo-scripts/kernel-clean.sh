#!/usr/bin/env bash
export PATH=/usr/bin:/usr/local/bin:/usr/sbin:/usr/bin/site_perl:/usr/bin/vendor_perl:/usr/bin/core_perl:$PATH
unset DISTCC_HOSTS
#
# =====================================================================
#  /home/builder/scripts/kernel-clean.sh
#
#  Purpose:
#    Perform a deterministic cleanup of the Linux kernel source tree
#    while preserving the .config file. This script removes build
#    artifacts and prepares the tree for a fresh distributed build.
#
#  Notes:
#    - ASCII-only, nano-safe, deterministic.
#    - No tabs, no Unicode, no timestamps.
#    - Must be run as builder on kubenode1.
#    - Does not delete .config.
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

if [ ! -d "$SRC" ]; then
    echo "ERROR: Kernel source directory not found: $SRC"
    exit 1
fi

cd "$SRC"

# ---------------------------------------------------------------------
#  Preserve .config
# ---------------------------------------------------------------------

if [ ! -f ".config" ]; then
    echo "ERROR: .config not found; refusing to clean"
    exit 1
fi

echo "Preserving .config"
cp .config .config.saved

# ---------------------------------------------------------------------
#  Clean build artifacts
# ---------------------------------------------------------------------

echo "Running make clean..."
make clean

echo "Running make mrproper (except .config)..."
make mrproper

# ---------------------------------------------------------------------
#  Restore .config
# ---------------------------------------------------------------------

echo "Restoring .config"
mv .config.saved .config

# ---------------------------------------------------------------------
#  Regenerate configuration headers
# ---------------------------------------------------------------------

echo "Regenerating configuration headers..."
make olddefconfig

echo "Kernel cleanup complete."
