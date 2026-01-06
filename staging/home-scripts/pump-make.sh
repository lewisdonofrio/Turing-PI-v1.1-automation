#!/bin/sh
set -eu

# ---------------------------------------------------------------------
#  /home/builder/scripts/pump-make.sh
#
#  Purpose:
#    Thin, deterministic wrapper for pump-mode distributed make.
#    Assumes pump include-server is already running (preflight).
#
#  Notes:
#    - ASCII-only, nano-safe, deterministic.
#    - No pump startup or shutdown here.
#    - No environment mutation beyond calling pump.
# ---------------------------------------------------------------------

# Must run as builder
if [ "$(whoami)" != "builder" ]; then
    echo "ERROR: pump-make must run as builder user"
    exit 1
fi

# Pump include-server must already be running
if ! pgrep -f include-server >/dev/null 2>&1; then
    echo "ERROR: pump include-server not running (preflight required)"
    exit 1
fi

# Ensure pump generates its own DISTCC_HOSTS based on ~/.distcc/hosts
unset DISTCC_HOSTS || true

# Hand off to pump (our shim in /home/builder/scripts/pump)
exec pump "$@"
