#!/bin/sh
set -euo pipefail

# =====================================================================
#  /home/builder/scripts/pump-make.sh
#
#  Purpose:
#    Thin, deterministic wrapper for pump-mode distributed make.
#    Assumes pump include-server is already running (preflight).
#
#  Notes:
#    - ASCII-only, nano-safe, deterministic.
#    - No pump startup or shutdown here.
#    - No environment mutation.
#    - No PATH overrides.
# =====================================================================

# ---------------------------------------------------------------------
#  Validation
# ---------------------------------------------------------------------

if [ "$(whoami)" != "builder" ]; then
    echo "ERROR: pump-make must run as builder user"
    exit 1
fi

if ! pgrep -f include-server >/dev/null 2>&1; then
    echo "ERROR: pump include-server not running (preflight required)"
    exit 1
fi

# ---------------------------------------------------------------------
#  Execute pump make
# ---------------------------------------------------------------------

exec pump make "$@"
