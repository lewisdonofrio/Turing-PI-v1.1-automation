#!/usr/bin/env bash
export DISTCC_HOSTS=""
#
# =====================================================================
#  /home/builder/scripts/kernel-run-all.sh
#
#  Purpose:
#    Execute the full distributed kernel build pipeline in sequence.
#    This script orchestrates cleanup, preparation, pump-mode build,
#    packaging, and artifact organization. Optional dashboard
#    integration is provided for tmux users.
#
#  Notes:
#    - ASCII-only, nano-safe, deterministic.
#    - No tabs, no Unicode, no timestamps.
#    - Must be run as builder on kubenode1.
#    - Each stage is executed explicitly and logged.
# =====================================================================
echo "DEBUG: HOME is $HOME"
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

SCRIPT_DIR="/home/builder/scripts"

# ---------------------------------------------------------------------
#  Optional dashboard
# ---------------------------------------------------------------------

if [ "${1:-}" = "--dashboard" ]; then
    echo "Launching cluster dashboard in tmux pane..."
    tmux split-window -v "$SCRIPT_DIR/kernel-cluster-dashboard.sh"
fi

# ---------------------------------------------------------------------
#  Pipeline execution
# ---------------------------------------------------------------------

echo "Running kernel-clean.sh"
"$SCRIPT_DIR/kernel-clean.sh"

echo "Running kernel-prep.sh"
"$SCRIPT_DIR/kernel-prep.sh"

echo "Running kernel-build.sh"
"$SCRIPT_DIR/kernel-build.sh"

echo "Running kernel-package.sh"
"$SCRIPT_DIR/kernel-package.sh"

echo "Running kernel-artifact-organizer.sh"
"$SCRIPT_DIR/kernel-artifact-organizer.sh"

echo "Full pipeline complete."
