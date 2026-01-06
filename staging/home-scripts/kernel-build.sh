#!/usr/bin/env bash
set -euo pipefail

# =====================================================================
#  /home/builder/scripts/kernel-build.sh
#
#  Purpose:
#    Deterministic ARMv7 + k3s kernel build using pump-mode distcc.
#    Requires kernel-build-preflight.sh to have run successfully.
#
#  Notes:
#    - ASCII-only, nano-safe, deterministic.
#    - Must run as builder on kubenode1.
#    - Preflight guarantees pump mode, PATH, CC/HOSTCC, and environment.
# =====================================================================

# ---------------------------------------------------------------------
#  Load pump-mode environment from preflight
# ---------------------------------------------------------------------

if [ -f /tmp/kernel-preflight.env ]; then
    . /tmp/kernel-preflight.env
else
    echo "ERROR: Preflight environment missing. Run kernel-build-preflight.sh first."
    exit 1
fi

# ---------------------------------------------------------------------
#  Verify preflight marker
# ---------------------------------------------------------------------

if [ ! -f /tmp/kernel-preflight.ok ]; then
    echo "ERROR: Preflight not run. Run kernel-build-preflight.sh first."
    exit 1
fi

# ---------------------------------------------------------------------
#  Single-instance lock
# ---------------------------------------------------------------------

LOCKFILE="/tmp/kernel-build.lock"
exec 9>"${LOCKFILE}"
if ! flock -n 9; then
    echo "ERROR: kernel-build already running (lockfile held)."
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
CONFIG_WRAPPER="/home/builder/scripts/run-k3s-kernel-config.sh"
PUMP_MAKE="/home/builder/scripts/pump-make.sh"

if [ ! -d "${SRC}" ]; then
    echo "ERROR: Kernel source directory not found: ${SRC}"
    exit 1
fi

if [ ! -x "${CONFIG_WRAPPER}" ]; then
    echo "ERROR: Config wrapper not executable: ${CONFIG_WRAPPER}"
    exit 1
fi

if [ ! -x "${PUMP_MAKE}" ]; then
    echo "ERROR: pump-make wrapper not executable: ${PUMP_MAKE}"
    exit 1
fi

mkdir -p "${LOGDIR}"
cd "${SRC}"

# ---------------------------------------------------------------------
#  Job count parsing
# ---------------------------------------------------------------------

RAW_JOBS="${1:-14}"
JOBS="${RAW_JOBS#j}"   # strip leading 'j' if present

if ! [[ "$JOBS" =~ ^[0-9]+$ ]]; then
    echo "ERROR: Invalid job count: ${RAW_JOBS}"
    exit 1
fi

echo "Compiler settings:"
echo "  CC=${CC:-unset}"
echo "  HOSTCC=${HOSTCC:-unset}"
echo "  Jobs=${JOBS}"

# ---------------------------------------------------------------------
#  Pump mode verification (no startup here)
# ---------------------------------------------------------------------

if ! pgrep -f include-server >/dev/null 2>&1; then
    echo "ERROR: pump include-server not running"
    exit 1
fi

# ---------------------------------------------------------------------
#  Logging setup
# ---------------------------------------------------------------------

STAMP=$(date +"%Y%m%d-%H%M%S")
LOGFILE="${LOGDIR}/build-${STAMP}.log"
LATEST="${LOGDIR}/latest.log"

echo "Starting kernel build"
echo "Logging to ${LOGFILE}"

START=$(date +%s)

# ---------------------------------------------------------------------
#  Stage 1: Config wrapper
# ---------------------------------------------------------------------

echo "[1/3] Running kernel config wrapper..."
"${CONFIG_WRAPPER}"

# ---------------------------------------------------------------------
#  Stage 2: Local prepare stage
# ---------------------------------------------------------------------

echo "[2/3] Running prepare stage (local only)..."
make ARCH=arm prepare

# ---------------------------------------------------------------------
#  Stage 3: Distributed build
# ---------------------------------------------------------------------

echo "[3/3] Running distributed build via pump-make..."

# ---------------------------------------------------------------------
#  CRITICAL FIX:
#    - CC must be "distcc gcc"
#    - HOSTCC must be "gcc"
#    - NEVER override HOSTCC to "distcc gcc"
# ---------------------------------------------------------------------

"${PUMP_MAKE}" \
    -j"${JOBS}" \
    ARCH=arm \
    CC="distcc gcc" \
    HOSTCC="gcc" \
    Image modules dtbs \
    2>&1 | tee "${LOGFILE}"

# ---------------------------------------------------------------------
#  Timing and summary
# ---------------------------------------------------------------------

END=$(date +%s)
ELAPSED=$((END - START))

ln -sf "${LOGFILE}" "${LATEST}"

echo "Build completed"
echo "Elapsed time: ${ELAPSED} seconds"
exit 0
