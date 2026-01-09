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

#!/bin/sh
set -eu

# Must run as builder
if [ "$(whoami)" != "builder" ]; then
    echo "ERROR: pump-make must run as builder user"
    exit 1
fi

echo "Pump-mode is wrapper-managed; include-server will start on demand."


# Ensure pump generates its own DISTCC_HOSTS based on ~/.distcc/hosts
unset DISTCC_HOSTS || true

# Correct: hand off to pump *make*
exec pump make "$@"
