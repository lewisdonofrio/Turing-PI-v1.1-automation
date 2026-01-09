#!/bin/bash
set -euo pipefail

# =====================================================================
#  kernel-build-preflight.sh
#
#  Purpose:
#    Deterministic, pump-mode-ready environment setup for ARMv7 kernel
#    builds. Produces a canonical environment file consumed by
#    kernel-build.sh. Ensures Kconfig always sees real gcc while
#    pump-mode distcc handles distributed compilation.
#
#  Doctrine:
#    - No PATH inheritance. No distcc shims in PATH.
#    - CC="distcc gcc" drives pump-mode.
#    - HOSTCC="gcc" always real.
#    - One authoritative environment file.
# =====================================================================

LOCKFILE="/tmp/kernel-preflight.lock"
ENVFILE="/tmp/kernel-preflight.env"
PRELOG="/home/builder/build-logs/preflight.log"
exec > >(while IFS= read -r line; do printf "[%s] %s\n" "$(date -u +"%Y-%m-%d %H:%M:%S")" "$line"; done | tee -a "$PRELOG") 2>&1

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
#  1. Clean logs and kernel artifacts
# ---------------------------------------------------------------------
echo "Cleaning old logs..."
rm -f /home/builder/build-logs/*.log 2>/dev/null || true

echo "Cleaning kernel build artifacts..."
make -C /home/builder/src/kernel mrproper >/dev/null 2>&1 || true

echo "Cleaning stale Kconfig/generated artifacts..."
find /home/builder/src/kernel -maxdepth 3 -type f \
    \( -name "auto.conf" -o -name "autoconf.h" -o -name "include/generated/*" \) \
    -delete 2>/dev/null || true
echo "Kconfig state cleaned (your .config preserved)."

# ---------------------------------------------------------------------
#  2. Reset distcc + pump include-server
# ---------------------------------------------------------------------
echo "Resetting distcc and pump include-server..."
pkill -f distcc 2>/dev/null || true
rm -rf /tmp/distcc-pump.* || true

# ---------------------------------------------------------------------
#  3. Source builder distcc environment
# ---------------------------------------------------------------------
echo "Sourcing builder distcc environment..."
BUILDER_ENV="/home/builder/builder-distcc-env-setup.sh"
if [[ ! -f "${BUILDER_ENV}" ]]; then
    echo "ERROR: Builder distcc environment missing: ${BUILDER_ENV}"
    exit 1
fi

# This script:
#   - Must NOT modify PATH (by doctrine).
#   - May prepend /home/builder/scripts to PATH.
#   - Sets DISTCC_* defaults.
# Safe to source multiple times.
source "${BUILDER_ENV}"

# Show hosts
HOSTFILE="/home/builder/.distcc/hosts"
if [[ ! -f "${HOSTFILE}" ]]; then
    echo "ERROR: distcc hostfile missing: ${HOSTFILE}"
    exit 1
fi

echo "Current distcc hosts:"
sed 's/^/  /' "${HOSTFILE}"

# ---------------------------------------------------------------------
# 3.5 Canonical PATH (no distcc shims)
# ---------------------------------------------------------------------
echo "Setting canonical PATH (no distcc shims)..."
export PATH="/home/builder/scripts:/usr/local/sbin:/usr/local/bin:/usr/bin:/usr/sbin:/sbin:/bin"
hash -r
echo "  PATH=${PATH}"

# ---------------------------------------------------------------------
#  4. Pump fitness + ground test
# ---------------------------------------------------------------------
echo "Running pump fitness check..."
/home/builder/scripts/pump-fitness-check.sh

echo "Running pump ground test..."
/home/builder/scripts/pump-ground-test.sh

echo "Pump validated and operational."

# ---------------------------------------------------------------------
#  6. Canonical compiler environment
# ---------------------------------------------------------------------
export CC="pump gcc"
# export CC="distcc gcc"
export HOSTCC="gcc"

# ---------------------------------------------------------------------
#  7. Write authoritative environment file
# ---------------------------------------------------------------------
echo "Writing environment to ${ENVFILE}..."
cat > "${ENVFILE}" <<EOF
export CC="${CC}"
export HOSTCC="${HOSTCC}"
export PATH="${PATH}"
# Pump-mode is wrapper-managed; no pump dir exported
EOF

echo "Preflight completed. Environment is ready for kernel-build.sh"
exit 0
