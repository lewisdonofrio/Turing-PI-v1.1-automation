#!/usr/bin/env bash
set -euo pipefail

# =====================================================================
#  /opt/ansible-k3s-cluster/scripts/kernel-build-preflight.sh
#
#  Purpose:
#    Deterministic, pump-mode-ready environment setup for ARMv7 kernel
#    builds. Produces a canonical environment file consumed by
#    kernel-build.sh and validates pump-mode operation before any
#    heavy work runs.
#
#  Runtime location:
#    /home/builder/scripts/kernel-build-preflight.sh
#
#  Usage:
#    - Must be run as builder on kubenode1.
#    - Prepares environment only; does NOT build the kernel.
#    - Run before ./kernel-build.sh:
#         cd /home/builder/scripts
#         ./kernel-build-preflight.sh
#
#  Doctrine:
#    - Kernel tree: /home/builder/linux
#    - No distcc shims in PATH.
#    - CC="pump gcc" (wrapper-managed pump-mode).
#    - HOSTCC="gcc" (always real).
#    - One authoritative environment file at /tmp/kernel-preflight.env.
#    - Preflight marker /tmp/kernel-preflight.ok gates kernel-build.sh.
# =====================================================================

LOCKFILE="/tmp/kernel-preflight.lock"
ENVFILE="/tmp/kernel-preflight.env"
OKFILE="/tmp/kernel-preflight.ok"
PRELOG="/home/builder/build-logs/preflight.log"
KERNEL_DIR="/home/builder/linux"

mkdir -p /home/builder/build-logs

# Timestamp stdout/stderr to preflight log
exec > >(while IFS= read -r line; do
    printf "[%s] %s\n" "$(date -u +"%Y-%m-%d %H:%M:%S")" "$line"
done | tee -a "$PRELOG") 2>&1

echo "==============================================================="
echo " kernel-build-preflight.sh - Pump-mode environment preparation"
echo "==============================================================="

# ---------------------------------------------------------------------
#  Locking
# ---------------------------------------------------------------------
if [[ -e "${LOCKFILE}" ]]; then
    echo "ERROR: kernel-build-preflight already running."
    exit 1
fi
echo $$ > "${LOCKFILE}"

cleanup() {
    rm -f "${LOCKFILE}"
}
trap cleanup EXIT

# ---------------------------------------------------------------------
#  1. Basic sanity checks
# ---------------------------------------------------------------------
echo "[1/5] Sanity checks..."

if [[ "$(whoami)" != "builder" ]]; then
    echo "ERROR: Must run as builder user"
    exit 1
fi

if [[ "$(hostname)" != "kubenode1" ]]; then
    echo "ERROR: Must run on kubenode1"
    exit 1
fi

if [[ ! -d "${KERNEL_DIR}" ]]; then
    echo "ERROR: Kernel directory not found at ${KERNEL_DIR}"
    exit 1
fi

echo "OK: Running as builder on kubenode1 with kernel dir ${KERNEL_DIR}"

# ---------------------------------------------------------------------
#  2. Clean logs and lightweight artifacts
# ---------------------------------------------------------------------
echo "[2/5] Cleaning old logs and lightweight artifacts..."

rm -f /home/builder/build-logs/*.log 2>/dev/null || true

find "${KERNEL_DIR}" -maxdepth 3 -type f \
    \( -name "auto.conf" -o -name "autoconf.h" \) \
    -delete 2>/dev/null || true

echo "OK: Logs cleaned and basic generated config artifacts reset."

# ---------------------------------------------------------------------
#  3. Reset distcc + pump include-server
# ---------------------------------------------------------------------
echo "[3/5] Resetting distcc and pump include-server..."

pkill -f distcc 2>/dev/null || true
rm -rf /tmp/distcc-pump.* || true

echo "OK: distcc and pump state cleared."

# ---------------------------------------------------------------------
#  4. Source builder distcc environment + canonical PATH
# ---------------------------------------------------------------------
echo "[4/5] Sourcing builder distcc environment..."

BUILDER_ENV="/home/builder/builder-distcc-env-setup.sh"
if [[ ! -f "${BUILDER_ENV}" ]]; then
    echo "ERROR: Builder distcc environment missing: ${BUILDER_ENV}"
    exit 1
fi

source "${BUILDER_ENV}"
export DISTCC_DIR="/home/builder/.distcc"

HOSTFILE="/home/builder/.distcc/hosts"
if [[ ! -f "${HOSTFILE}" ]]; then
    echo "ERROR: distcc hostfile missing: ${HOSTFILE}"
    exit 1
fi

echo "Current distcc hosts:"
sed 's/^/  /' "${HOSTFILE}"

# ---------------------------------------------------------------------
#  Derive pump-mode DISTCC_HOSTS from canonical hostfile
# ---------------------------------------------------------------------
DISTCC_HOSTS=$(awk '{print $1}' "${HOSTFILE}" \
    | sed 's/\/[0-9]\+$//' \
    | sed 's/$/,cpp/' \
    | xargs)

export DISTCC_HOSTS
echo "Pump-mode DISTCC_HOSTS: ${DISTCC_HOSTS}"

echo "Setting canonical PATH (no distcc shims)..."
export PATH="/home/builder/scripts:$PATH"
hash -r
echo "  PATH=${PATH}"

# ---------------------------------------------------------------------
#  5. Canonical compiler environment (must come BEFORE envfile write)
# ---------------------------------------------------------------------
export ARCH=arm
export REAL_GCC="gcc"
export PUMP_GCC_CMD="pump gcc"
export CC="gcc"
export HOSTCC="gcc"
export CROSS_COMPILE=""

# ---------------------------------------------------------------------
#  Write environment file BEFORE pump-ground-test wipes environment
# ---------------------------------------------------------------------
echo "Writing environment to ${ENVFILE}..."
cat > "${ENVFILE}" <<EOF
export ARCH="${ARCH}"
export REAL_GCC="${REAL_GCC}"
export PUMP_GCC_CMD="${PUMP_GCC_CMD}"
export CC="gcc"
export HOSTCC="gcc"
export CROSS_COMPILE="${CROSS_COMPILE}"
export DISTCC_HOSTS="${DISTCC_HOSTS}"
export PATH="/home/builder/scripts:$PATH"
# Pump-mode is shim-managed; no pump dir exported
EOF
# ---------------------------------------------------------------------
#  5. Pump fitness + ground test
# ---------------------------------------------------------------------
echo "[5/5] Running pump fitness + ground test..."

/home/builder/scripts/pump-fitness-check.sh
/home/builder/scripts/pump-ground-test.sh

echo "OK: Pump-mode validated and operational."

# ---------------------------------------------------------------------
#  6. Canonical compiler environment + envfile + marker
# ---------------------------------------------------------------------

echo "Creating preflight marker ${OKFILE}..."
touch "${OKFILE}"

echo "==============================================================="
echo " Preflight completed. Environment is ready for kernel-build.sh"
echo "==============================================================="

exit 0
