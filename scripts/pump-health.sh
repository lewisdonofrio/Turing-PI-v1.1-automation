#!/usr/bin/env bash
# =============================================================================
# File: /home/builder/scripts/pump-health.sh
# =============================================================================
# Purpose:
#   Check if shim-based distcc-pump include-server appears healthy.
#
# Exit codes:
#   0 - healthy
#   1 - not healthy / not running
#
# Notes:
#   This script does not rely on INCLUDE_SERVER_* environment variables.
#   Health is determined by include-server process presence and socket state.
#   No tabs, ASCII-only.
# =============================================================================

set -eu

# Detect include-server process
PID="$(pgrep -f include-server || true)"

if [ -z "${PID}" ]; then
    echo "pump-health: include-server not running." >&2
    exit 1
fi

# Locate the most recent pump socket directory
SOCKET_DIR="$(ls -td /tmp/distcc-pump.* 2>/dev/null | head -n1 || true)"

if [ -z "${SOCKET_DIR}" ]; then
    echo "pump-health: no pump socket directory found." >&2
    exit 1
fi

SOCKET_PATH="${SOCKET_DIR}/socket"

if [ ! -S "${SOCKET_PATH}" ]; then
    echo "pump-health: include-server socket missing: ${SOCKET_PATH}" >&2
    exit 1
fi

echo "pump-health: include-server running (pid ${PID}), socket OK."
exit 0
