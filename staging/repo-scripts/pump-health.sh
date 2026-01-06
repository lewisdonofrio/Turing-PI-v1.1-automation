#!/usr/bin/env bash
# =============================================================================
# File: /home/builder/scripts/pump-health.sh
# =============================================================================
# Purpose:
#   Check if distcc-pump include server appears healthy.
#
# Exit codes:
#   0 - healthy
#   1 - not healthy / not running
# =============================================================================

set -eu

# Pump sets these environment variables when active.
INCLUDE_SERVER_DIR="${INCLUDE_SERVER_DIR:-}"
INCLUDE_SERVER_PORT="${INCLUDE_SERVER_PORT:-}"

if [ -z "${INCLUDE_SERVER_DIR}" ] || [ -z "${INCLUDE_SERVER_PORT}" ]; then
    echo "pump-health: INCLUDE_SERVER_* not set. Pump not active." >&2
    exit 1
fi

if [ ! -S "${INCLUDE_SERVER_PORT}" ]; then
    echo "pump-health: include server socket missing: ${INCLUDE_SERVER_PORT}" >&2
    exit 1
fi

# Optional: sanity check process is still there
if [ -n "${INCLUDE_SERVER_PID:-}" ]; then
    if ! kill -0 "${INCLUDE_SERVER_PID}" 2>/dev/null; then
        echo "pump-health: include server PID ${INCLUDE_SERVER_PID} not running." >&2
        exit 1
    fi
fi

echo "pump-health: include server appears healthy."
exit 0
