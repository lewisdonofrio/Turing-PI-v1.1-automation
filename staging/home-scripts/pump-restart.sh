#!/usr/bin/env bash
# =============================================================================
# File: /home/builder/scripts/pump-restart.sh
# =============================================================================
# Purpose:
#   Restart shim-based distcc-pump include-server and validate health.
#
# Usage:
#   /home/builder/scripts/pump-restart.sh
#
# Notes:
#   This script no longer calls "pump --startup" or "pump --shutdown".
#   The system pump binary is not used. The shim architecture controls
#   include-server directly. No tabs, ASCII-only.
# =============================================================================

set -eu

PUMP_SHIM="/usr/local/lib/distcc-pump/pump-shim"
PUMP_HEALTH="/home/builder/scripts/pump-health.sh"

echo "pump-restart: shutting down existing pump (if any)..."
pkill -f include-server || true
sleep 1

echo "pump-restart: starting pump via shim..."
# Invoke shim once to trigger include-server startup
"${PUMP_SHIM}" --version >/dev/null 2>&1 || true
sleep 1

echo "pump-restart: checking pump health..."
if ! "${PUMP_HEALTH}"; then
    echo "pump-restart: pump health check FAILED." >&2
    exit 1
fi

echo "pump-restart: pump is healthy."
exit 0
