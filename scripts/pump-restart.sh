#!/usr/bin/env bash
# =============================================================================
# File: /home/builder/scripts/pump-restart.sh
# =============================================================================
# Purpose:
#   Restart distcc-pump include server and validate health.
#
# Usage:
#   /home/builder/scripts/pump-restart.sh
# =============================================================================

set -eu

PUMP_HEALTH="/home/builder/scripts/pump-health.sh"

echo "pump-restart: shutting down existing pump (if any)..."
pump --shutdown || true

echo "pump-restart: starting pump..."
pump --startup

echo "pump-restart: checking pump health..."
if ! "${PUMP_HEALTH}"; then
    echo "pump-restart: pump health check FAILED." >&2
    exit 1
fi

echo "pump-restart: pump is healthy."
exit 0
