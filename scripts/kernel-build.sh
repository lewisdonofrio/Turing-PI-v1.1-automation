#!/usr/bin/env bash
set -euo pipefail

# =====================================================================
#  kernel-build.sh (out-of-tree, ARMv7, distcc edition)
#
#  Doctrine:
#    - Source tree: /home/builder/src/kernel
#    - OUT_DIR:     /home/builder/kernel-out
#    - .config MUST live in OUT_DIR, not the source tree
#    - Source tree must be pristine (git clean -fdx + mrproper)
#    - Local gcc for prepare + syncconfig
#    - distcc gcc for parallel build
#    - Full ARMv7 build: Image, zImage, dtbs, modules
# =====================================================================

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

SRC_DIR="/home/builder/src/kernel"
OUT_DIR="/home/builder/kernel-out"
LOGDIR="/home/builder/build-logs"
CROSS_COMPILE=""
export PATH=/home/builder/rpi-tools/arm-bcm2708/arm-linux-gnueabihf/bin:$PATH

if [[ ! -d "${SRC_DIR}" ]]; then
    echo "ERROR: Kernel source directory not found: ${SRC_DIR}"
    exit 1
fi

mkdir -p "${LOGDIR}"
mkdir -p "${OUT_DIR}"

cd "${SRC_DIR}"

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

echo "=============================================================="
echo "  KERNEL BUILD: OUT-OF-TREE ARMv7 BUILD (distcc accelerated)"
echo "=============================================================="
echo "Source directory: ${SRC_DIR}"
echo "Output directory: ${OUT_DIR}"
echo "Jobs:             ${JOBS}"
echo

# ---------------------------------------------------------------------
#  Ensure source tree is pristine
# ---------------------------------------------------------------------
if [[ -n "$(git status --porcelain)" ]]; then
    echo "ERROR: Source tree is not clean."
    echo "Run: git clean -fdx && make mrproper"
    exit 1
fi

echo "Source tree is clean."

# ---------------------------------------------------------------------
#  Ensure .config exists in OUT_DIR
# ---------------------------------------------------------------------
if [[ ! -f "${OUT_DIR}/.config" ]]; then
    echo "ERROR: No .config found in ${OUT_DIR}"
    echo "Copy your config into OUT_DIR:"
    echo "  cp /opt/ansible-k3s-cluster/kernel-configs/<config> ${OUT_DIR}/.config"
    exit 1
fi

echo ".config found in OUT_DIR."

# ---------------------------------------------------------------------
#  Logging setup
# ---------------------------------------------------------------------
STAMP=$(date +"%Y%m%d-%H%M%S")
LOGFILE="${LOGDIR}/build-${STAMP}.log"
LATEST="${LOGDIR}/latest.log"

echo "Logging to ${LOGFILE}"
START=$(date +%s)

# ---------------------------------------------------------------------
#  Stage 1: prepare (local gcc)
# ---------------------------------------------------------------------
echo "[1/4] Running prepare (local gcc)..."

make \
    ARCH=arm \
     \
    CC=gcc \
    HOSTCC=gcc \
    O="${OUT_DIR}" \
    prepare

# ---------------------------------------------------------------------
#  Stage 2: syncconfig (local gcc)
# ---------------------------------------------------------------------
echo "[2/4] Running syncconfig (local gcc)..."

make \
    ARCH=arm \
     \
    CC=gcc \
    HOSTCC=gcc \
    O="${OUT_DIR}" \
    syncconfig

# ---------------------------------------------------------------------
#  Stage 3: Distributed build via plain distcc
# ---------------------------------------------------------------------
echo "[3/4] Running distributed build via distcc..."

export DISTCC_HOSTS="\
kubenode2.home.lab/4 \
kubenode3.home.lab/4 \
kubenode4.home.lab/4 \
kubenode5.home.lab/4 \
kubenode6.home.lab/4 \
kubenode7.home.lab/4"

make -j"${JOBS}" \
    ARCH=arm \
     \
    CC="distcc gcc" \
    HOSTCC=gcc \
    O="${OUT_DIR}" \
    Image zImage dtbs modules \
    2>&1 | tee "${LOGFILE}"

# ---------------------------------------------------------------------
#  Stage 4: Install modules
# ---------------------------------------------------------------------

echo "[4/4] Installing modules into OUT_DIR..."

# Create the target module directory inside OUT_DIR
KREL=$(make -s -C "${SRC_DIR}" O="${OUT_DIR}" ARCH=arm kernelrelease)
MODDIR="${OUT_DIR}/lib/modules/${KREL}"

mkdir -p "${MODDIR}"

# Install modules into OUT_DIR instead of /lib/modules
make -C "${SRC_DIR}" \
     O="${OUT_DIR}" \
     ARCH=arm \
     INSTALL_MOD_PATH="${OUT_DIR}" \
     modules_install

# Create the canonical 'build' symlink expected by depmod and modprobe
ln -sf "${OUT_DIR}" "${MODDIR}/build"

echo "Modules installed to: ${MODDIR}"

# ---------------------------------------------------------------------
#  Timing and summary
# ---------------------------------------------------------------------
END=$(date +%s)
ELAPSED=$((END - START))

ln -sf "${LOGFILE}" "${LATEST}"

echo
echo "=============================================================="
echo "  KERNEL BUILD COMPLETE"
echo "=============================================================="
echo "Artifacts located in: ${OUT_DIR}"
echo "Elapsed time: ${ELAPSED} seconds"
echo "=============================================================="
exit 0
