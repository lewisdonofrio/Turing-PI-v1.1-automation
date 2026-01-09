#!/bin/bash
# /home/builder/scripts/pump-restart.sh
# Purpose: Safely restart pump-mode include-server using the environment created
#          by kernel-build-preflight.sh. Detects stale or missing preflight state.
# Notes:
#   - ASCII-only, nano-safe
#   - Must NOT initialize pump-mode from scratch
#   - Must NOT set DISTCC_HOSTS
#   - Must NOT override CC/HOSTCC/PATH
#   - Must ONLY source /tmp/kernel-preflight.env and restart include-server

set -euo pipefail

ENV_FILE="/tmp/kernel-preflight.env"
LOCK_FILE="/tmp/kernel-preflight.lock"
OK_FILE="/tmp/kernel-preflight.ok"

echo "pump-restart: loading preflight environment..."

# ---------------------------------------------------------------------------
# 1. Verify preflight has run
# ---------------------------------------------------------------------------
if [[ ! -f "$ENV_FILE" ]]; then
    echo "ERROR: Preflight environment missing."
    echo "Run kernel-build-preflight.sh first."
    exit 1
fi

if [[ ! -f "$OK_FILE" ]]; then
    echo "ERROR: Preflight did not complete successfully."
    echo "Run kernel-build-preflight.sh first."
    exit 1
fi

# ---------------------------------------------------------------------------
# 2. Load the environment exactly as preflight created it
# ---------------------------------------------------------------------------
source "$ENV_FILE"

# Validate INCLUDE_SERVER_PORT
if [[ -z "${INCLUDE_SERVER_PORT:-}" ]]; then
    echo "ERROR: INCLUDE_SERVER_PORT missing from preflight environment."
    echo "Run kernel-build-preflight.sh again."
    exit 1
fi

# Validate pump socket directory
if [[ ! -d "$DISTCC_PUMP_DIR" ]]; then
    echo "ERROR: Pump socket directory missing: $DISTCC_PUMP_DIR"
    echo "This usually happens after a reboot or /tmp cleanup."
    echo "Run kernel-build-preflight.sh again."
    exit 1
fi

# Validate include-server-wrapper exists
if ! command -v include-server-wrapper >/dev/null 2>&1; then
    echo "ERROR: include-server-wrapper not found in PATH."
    echo "Your preflight environment may be stale."
    echo "Run kernel-build-preflight.sh again."
    exit 1
fi

# ---------------------------------------------------------------------------
# 3. Restart include-server safely
# ---------------------------------------------------------------------------
echo "pump-restart: shutting down existing pump (if any)..."
pkill -f include-server || true
sleep 1

echo "pump-restart: starting include-server..."
include-server-wrapper --daemon

sleep 1

# ---------------------------------------------------------------------------
# 4. Verify pump health
# ---------------------------------------------------------------------------
echo "pump-restart: verifying pump health..."

if pgrep -f include-server >/dev/null 2>&1; then
    echo "pump-restart: pump is healthy."
    exit 0
else
    echo "pump-restart: pump health check FAILED."
    echo "Run kernel-build-preflight.sh to reinitialize pump-mode."
    exit 1
fi
