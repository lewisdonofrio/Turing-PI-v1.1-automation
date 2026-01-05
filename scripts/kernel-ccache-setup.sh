#!/usr/bin/env bash
#
# =====================================================================
#  /home/builder/scripts/kernel-ccache-setup.sh
#
#  Purpose:
#    Configure ccache for use with distributed kernel builds. This
#    script sets up the cache directory, size limits, and environment
#    variables required for reproducible pump-mode builds.
#
#  Notes:
#    - ASCII-only, nano-safe, deterministic.
#    - No tabs, no Unicode, no timestamps.
#    - Must be run as builder on kubenode1.
#    - Does not modify system-wide configuration.
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

# ---------------------------------------------------------------------
#  ccache directory setup
# ---------------------------------------------------------------------

CCACHE_DIR="/home/builder/.ccache"

mkdir -p "$CCACHE_DIR"

echo "Configuring ccache directory at $CCACHE_DIR"

# ---------------------------------------------------------------------
#  ccache configuration
# ---------------------------------------------------------------------

ccache --set-config=cache_dir="$CCACHE_DIR"
ccache --set-config=max_size=5G
ccache --set-config=compression=true
ccache --set-config=sloppiness=file_macro,time_macros

# ---------------------------------------------------------------------
#  Environment variables for kernel builds
# ---------------------------------------------------------------------

echo "Exporting ccache environment variables"

export CCACHE_DIR="$CCACHE_DIR"
export CC="ccache gcc"
export CXX="ccache g++"

# ---------------------------------------------------------------------
#  Summary
# ---------------------------------------------------------------------

echo "ccache setup complete."
echo "Current ccache stats:"
ccache -s
