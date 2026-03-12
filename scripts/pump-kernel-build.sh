#!/usr/bin/env bash
set -euo pipefail

# NEW: inherit canonical pump-mode environment
source /tmp/kernel-preflight.env 2>/dev/null || true

# =====================================================================
#  /opt/ansible-k3s-cluster/scripts/kernel-build.sh
#
#  Purpose:
#    Deterministic ARMv7 kernel build for CM3+ workers using pump-mode
#    distcc. Consumes environment prepared by kernel-build-preflight.sh
#    and builds a fully bootable RPi kernel: Image + modules + dtbs.
#
#  Runtime location:
#    /home/builder/scripts/kernel-build.sh
#
#  Usage:
#    - Must be run as builder on kubenode1.
#    - Requires a valid .config in /home/builder/linux.
#    - Preflight must be run first:
#         cd /home/builder/scripts
#         ./kernel-build-preflight.sh
#         ./kernel-build.sh          # optional arg: j8, j12 (default j12)
#
#  Doctrine:
#    - Kernel tree: /home/builder/linux
#    - Environment from /tmp/kernel-preflight.env
#    - Preflight marker /tmp/kernel-preflight.ok must exist.
#    - CC="pump gcc" (wrapper-managed pump-mode).
#    - HOSTCC="gcc" (real compiler for prepare/syncconfig).
# =====================================================================

# ---------------------------------------------------------------------
#  Load pump-mode environment from preflight
# ---------------------------------------------------------------------
ENVFILE="/tmp/kernel-preflight.env"
OKFILE="/tmp/kernel-preflight.ok"

if [[ -f "${ENVFILE}" ]]; then
    # shellcheck source=/tmp/kernel-preflight.env
    . "${ENVFILE}"
else
    echo "ERROR: Preflight environment missing (${ENVFILE}). Run kernel-build-preflight.sh first."
    exit 1
fi

if [[ ! -f "${OKFILE}" ]]; then
    echo "ERROR: Preflight marker missing (${OKFILE}). Run kernel-build-preflight.sh first."
    exit 1
fi

# ---------------------------------------------------------------------
#  Single-instance lock
# ---------------------------------------------------------------------
LOCKFILE="/tmp/kernel-build.lock"

# Stale lockfile cleanup
if [ -e "$LOCKFILE" ]; then
    if ! lsof "$LOCKFILE" >/dev/null 2>&1; then
        echo "Stale lockfile detected; removing..."
        rm -f "$LOCKFILE"
    else
        echo "ERROR: kernel-build already running (lockfile held)."
        exit 1
    fi
fi

exec 9>"${LOCKFILE}"
if ! flock -n 9; then
    echo "ERROR: kernel-build already running (lockfile held)."
    exit 1
fi

# ---------------------------------------------------------------------
#  Environment validation
# ---------------------------------------------------------------------
if [[ "$(whoami)" != "builder" ]]; then
    echo "ERROR: Must run as builder user"
    exit 1
fi

if [[ "$(hostname)" != "kubenode1" ]]; then
    echo "ERROR: Must run on kubenode1"
    exit 1
fi

KERNEL_DIR="/home/builder/linux"
LOGDIR="/home/builder/build-logs"
PUMP_MAKE="/usr/bin/pump"
#PUMP_MAKE="/home/builder/scripts/pump-make.sh"

if [[ ! -d "${KERNEL_DIR}" ]]; then
    echo "ERROR: Kernel source directory not found: ${KERNEL_DIR}"
    exit 1
fi

if [[ ! -x "${PUMP_MAKE}" ]]; then
    echo "ERROR: pump-make wrapper not executable: ${PUMP_MAKE}"
    exit 1
fi

mkdir -p "${LOGDIR}"
cd "${KERNEL_DIR}"

# ---------------------------------------------------------------------
#  Job count parsing (default j12, max j12)
# ---------------------------------------------------------------------
RAW_JOBS="${1:-12}"
JOBS="${RAW_JOBS#j}"

if ! [[ "${JOBS}" =~ ^[0-9]+$ ]]; then
    echo "ERROR: Invalid job count: ${RAW_JOBS}"
    exit 1
fi

if [[ "${JOBS}" -gt 12 ]]; then
    echo "ERROR: Maximum allowed job count is 12"
    exit 1
fi

echo "Compiler settings:"
echo "  CC=${CC:-unset}"
echo "  HOSTCC=${HOSTCC:-unset}"
echo "  Jobs=${JOBS}"

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
#  Stage 1: Local prepare stage (real gcc only)
# ---------------------------------------------------------------------
echo "[1/3] Running prepare stage (local only, real gcc)..."

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
#  Stage 2: Pre-syncconfig (local, real gcc)
# ---------------------------------------------------------------------
echo "[2/3] Running syncconfig (local, real gcc)..."

REAL_CC="${CC:-}"
REAL_HOSTCC="${HOSTCC:-}"
REAL_PATH="${PATH:-}"

export CC="gcc"
export HOSTCC="gcc"
export PATH="/usr/local/sbin:/usr/local/sbin:/usr/local/bin:/usr/bin:/usr/sbin:/sbin:/bin"

make ARCH=arm syncconfig

export CC="${REAL_CC}"
export HOSTCC="${REAL_HOSTCC}"
export PATH="${REAL_PATH}"

# ---------------------------------------------------------------------
#  Stage 3: Distributed build via pump-make (Image + modules + dtbs)
#  Use a clean PATH for pump/distcc to avoid /usr/lib/distcc/bin wrapping gcc
# ---------------------------------------------------------------------
CLEAN_PATH="/usr/bin:/bin:/usr/local/bin:/usr/sbin:/sbin:/usr/local/sbin"
export PATH="${CLEAN_PATH}"
REAL_PATH="${PATH:-}"
	

echo "[3/3] Running distributed build via pump-make (Image modules dtbs)..."
# Force distcc for distributed build
export CC="distcc gcc"
export HOSTCC="gcc"
export DISTCC_HOSTS="kubenode2.home.lab/4 kubenode3.home.lab/4 kubenode4.home.lab/4 kubenode5.home.lab/4 kubenode6.home.lab/4 kubenode7.home.lab/4"

echo "DEBUG: DISTCC_HOSTS at pump invocation:"
echo "  DISTCC_HOSTS=${DISTCC_HOSTS:-<unset>}"
echo "DEBUG: PATH=${PATH}"

echo "Pre-running syncconfig under real gcc to prevent pump recursion..."
make -s ARCH=arm CC=gcc syncconfig
export KCONFIG_NOSILENTUPDATE=1
touch .config
touch include/config/auto.conf
touch include/generated/autoconf.h
touch include/generated/rustc_cfg 2>/dev/null || true
export CC="distcc gcc"
export HOSTCC="gcc"

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
END
END=$(date +%s)
ELAPSED=$((END - START))

ln -sf "${LOGFILE}" "${LATEST}"

echo "Build completed"
# Restore original PATH after build
if [[ -n "${REAL_PATH:-}" ]]; then
  export PATH="${REAL_PATH}"
fi

echo "Elapsed time: ${ELAPSED} seconds"
exit 0
