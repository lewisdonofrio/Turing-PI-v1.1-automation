#!/bin/sh
set -eu

# ---------------------------------------------------------------------
#  /home/builder/scripts/kernel-build-preflight.sh
#
#  Purpose:
#    Deterministic preflight readiness check for kernel builds.
#    Ensures the environment is clean, stable, and pump-ready before
#    running kernel-build.sh with a new job count.
#
#  Notes:
#    - ASCII-only, nano-safe, deterministic.
#    - Safe to run repeatedly.
# ---------------------------------------------------------------------

# ---------------------------------------------------------------------
#  Single-instance lock
# ---------------------------------------------------------------------

LOCKFILE="/tmp/kernel-preflight.lock"
exec 9>"${LOCKFILE}"
if ! flock -n 9; then
    echo "ERROR: kernel-build-preflight already running (lockfile held)."
    exit 1
fi

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

SRC="/home/builder/src/kernel"
LOGDIR="/home/builder/build-logs"
BUILDER_ENV="/home/builder/builder-distcc-env-setup.sh"

if [ ! -d "${SRC}" ]; then
    echo "ERROR: Kernel source directory missing: ${SRC}"
    exit 1
fi

if [ ! -f "${BUILDER_ENV}" ]; then
    echo "ERROR: Builder distcc environment missing: ${BUILDER_ENV}"
    exit 1
fi

mkdir -p "${LOGDIR}"

# ---------------------------------------------------------------------
#  Clean logs
# ---------------------------------------------------------------------

echo "Cleaning old logs..."
rm -f "${LOGDIR}/latest.log"

# ---------------------------------------------------------------------
#  Clean kernel build artifacts (safe clean)
# ---------------------------------------------------------------------

echo "Cleaning kernel build artifacts..."
cd "${SRC}"
make ARCH=arm clean

# ---------------------------------------------------------------------
#  Reset distcc and pump include-server
# ---------------------------------------------------------------------

echo "Resetting distcc and pump include-server..."
pkill -f include-server 2>/dev/null || true
pkill -f distcc 2>/dev/null || true

# ---------------------------------------------------------------------
#  Source builder environment
# ---------------------------------------------------------------------

echo "Sourcing builder distcc environment..."
# shellcheck disable=SC1090
. "${BUILDER_ENV}"

# ---------------------------------------------------------------------
#  Pump mode: enforce no DISTCC_HOSTS override
# ---------------------------------------------------------------------

if [ -n "${DISTCC_HOSTS:-}" ]; then
    echo "ERROR: DISTCC_HOSTS is set. Pump mode requires it to be unset."
    exit 1
fi

# ---------------------------------------------------------------------
#  Pump mode: validate hosts file
# ---------------------------------------------------------------------

HOSTS_FILE="${HOME}/.distcc/hosts"

if [ ! -f "${HOSTS_FILE}" ]; then
    echo "ERROR: Missing distcc hosts file: ${HOSTS_FILE}"
    exit 1
fi

PERM="$(stat -c %a "${HOSTS_FILE}")"
if [ "${PERM}" != "600" ]; then
    echo "ERROR: distcc hosts file must be chmod 600 (current ${PERM})"
    exit 1
fi

if grep -Eq ',cpp|,lzo' "${HOSTS_FILE}"; then
    echo "ERROR: Hostfile contains manual ',cpp' or ',lzo'."
    echo "Pump mode manages these automatically. Hostfile must contain only '/N' entries."
    exit 1
fi

echo "Hostfile validated for pump mode (no manual ,cpp or ,lzo)."
echo "Current distcc hosts:"
cat "${HOSTS_FILE}"

# ---------------------------------------------------------------------
#  Pump mode: clean stale pump directories
# ---------------------------------------------------------------------

echo "Cleaning stale pump directories..."
rm -rf /tmp/distcc-pump.*

# ---------------------------------------------------------------------
#  Pump mode: create pump directory
# ---------------------------------------------------------------------

INCLUDE_SERVER_DIR="/tmp/distcc-pump.$$"
mkdir -p "${INCLUDE_SERVER_DIR}"
export INCLUDE_SERVER_DIR
export INCLUDE_SERVER_PORT="${INCLUDE_SERVER_DIR}/socket"

# ---------------------------------------------------------------------
#  Persist pump-mode environment for kernel-build.sh
# ---------------------------------------------------------------------
# FIXED: HOSTCC must be gcc, not distcc gcc
# FIXED: PATH must preserve /home/builder/scripts first

cat > /tmp/kernel-preflight.env <<EOF
export INCLUDE_SERVER_DIR="${INCLUDE_SERVER_DIR}"
export INCLUDE_SERVER_PORT="${INCLUDE_SERVER_PORT}"
export PATH="/home/builder/scripts:${PATH}"
export CC="distcc gcc"
export HOSTCC="gcc"
EOF

# ---------------------------------------------------------------------
#  Pump mode: start include-server
# ---------------------------------------------------------------------

echo "Starting pump include-server..."

include-server-wrapper \
    --port "${INCLUDE_SERVER_PORT}" \
    --pid_file "${INCLUDE_SERVER_DIR}/pid" &
sleep 1

# ---------------------------------------------------------------------
#  Pump mode: verify include-server is alive
# ---------------------------------------------------------------------

if ! pgrep -f include-server >/dev/null 2>&1; then
    echo "ERROR: pump include-server failed to start."
    exit 1
fi

# ---------------------------------------------------------------------
#  Enforce correct PATH and CC/HOSTCC
# ---------------------------------------------------------------------
# FIXED: remove legacy /usr/lib/distcc/bin
# FIXED: enforce builder scripts first

export PATH="/home/builder/scripts:${PATH}"
export CC="distcc gcc"
export HOSTCC="gcc"

echo "Compiler settings:"
echo "  CC=${CC}"
echo "  HOSTCC=${HOSTCC}"

# ---------------------------------------------------------------------
#  Pump mode summary
# ---------------------------------------------------------------------

echo "Pump mode active:"
echo "  INCLUDE_SERVER_PID=$(pgrep -f include-server || echo "<none>")"
echo "  Hosts:"
distcc --show-hosts || true

# ---------------------------------------------------------------------
#  Mark preflight as completed
# ---------------------------------------------------------------------

touch /tmp/kernel-preflight.ok

echo "Preflight completed. Environment is ready for kernel-build.sh"
exit 0
