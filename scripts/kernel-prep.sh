#!/usr/bin/env bash
unset DISTCC_HOSTS
#
# =====================================================================
#  /home/builder/scripts/kernel-prep.sh
#
#  Purpose:
#    Prepare the Linux kernel source tree for a reproducible,
#    pump-mode-enabled distributed build using distcc.
#
#  Notes:
#    - ASCII-only, nano-safe, deterministic.
#    - No tabs, no Unicode, no timestamps.
#    - Must be run as builder on kubenode1.
#    - Assumes kernel-clean.sh has already been executed.
#    - Does NOT perform any cleanup.
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
#  Validate .config exists
# ---------------------------------------------------------------------

if [ ! -f ".config" ]; then
    echo "ERROR: .config missing; run kernel-clean.sh first"
    exit 1
fi

# ---------------------------------------------------------------------
#  Regenerate configuration artifacts
# ---------------------------------------------------------------------

echo "Regenerating configuration headers..."
make olddefconfig

# ---------------------------------------------------------------------
#  Build host tools (required before pump-mode build)
# ---------------------------------------------------------------------

echo "Building host tools..."
make scripts

echo "Kernel prep complete."
