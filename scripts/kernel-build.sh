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
#  Job count parsing (default j12, max j12)
# ---------------------------------------------------------------------

RAW_JOBS="${1:-12}"
JOBS="${RAW_JOBS#j}"

if ! [[ "${JOBS}" =~ ^[0-9]+$ ]]; then
    echo "ERROR: Invalid job count: ${RAW_JOBS}"
    exit 1
fi

if [ "${JOBS}" -gt 12 ]; then
    echo "ERROR: Maximum allowed job count is 12"
    exit 1
fi

echo "Compiler settings:"
echo "  CC=${CC:-unset}"
echo "  HOSTCC=${HOSTCC:-unset}"
echo "  Jobs=${JOBS}"

# ---------------------------------------------------------------------
#  Pump-mode verification (doctrine-aligned)
# ---------------------------------------------------------------------

echo "Pump-mode is wrapper-managed; include-server will start on demand."

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
#  CRITICAL:
#    CC/HOSTCC must be exported BEFORE prepare stage
#    Preflight already set CC="pump gcc"
# ---------------------------------------------------------------------

export CC="${CC}"
export HOSTCC="${HOSTCC}"

# ---------------------------------------------------------------------
#  Stage 1: Config wrapper
# ---------------------------------------------------------------------

echo "[1/3] Running kernel config wrapper..."
"${CONFIG_WRAPPER}"

# ---------------------------------------------------------------------
#  Stage 2: Local prepare stage (real gcc only)
# ---------------------------------------------------------------------

echo "[2/3] Running prepare stage (local only)..."

REAL_CC="${CC:-}"
REAL_HOSTCC="${HOSTCC:-}"
REAL_PATH="${PATH:-}"

export CC="gcc"
export HOSTCC="gcc"
export PATH="/usr/local/sbin:/usr/local/bin:/usr/bin:/usr/sbin:/sbin:/bin"

make ARCH=arm prepare

export CC="${REAL_CC}"
export HOSTCC="${REAL_HOSTCC}"
export PATH="${REAL_PATH}"

# ---------------------------------------------------------------------
#  Stage 3: Pre-syncconfig (real gcc only)
# ---------------------------------------------------------------------

echo "[3/3] Pre-syncconfig (local, real gcc)..."

REAL_CC="${CC:-}"
REAL_HOSTCC="${HOSTCC:-}"
REAL_PATH="${PATH:-}"

export CC="gcc"
export HOSTCC="gcc"
export PATH="/usr/local/sbin:/usr/local/bin:/usr/bin:/usr/sbin:/sbin:/bin"

make ARCH=arm syncconfig

export CC="${REAL_CC}"
export HOSTCC="${REAL_HOSTCC}"
export PATH="${REAL_PATH}"

# ---------------------------------------------------------------------
#  Stage 3: Distributed build via pump-make
# ---------------------------------------------------------------------

echo "[3/3] Running distributed build via pump-make..."

"${PUMP_MAKE}" \
    -j"${JOBS}" \
    ARCH=arm \
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
