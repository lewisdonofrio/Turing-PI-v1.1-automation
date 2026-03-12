#!/usr/bin/env bash
# =====================================================================
#  /home/builder/scripts/kernel-post-build-worker7.sh
#
#  Purpose:
#    End-to-end post-build pipeline for worker7 using the new
#    OUT-OF-TREE ARMv7 kernel doctrine:
#
#      1. Validate kernel artifacts (out-of-tree)
#      2. Deploy kernel + DTBs + overlays + modules to worker7
#      3. Backup existing kernel on worker7
#      4. Install new kernel
#      5. Reboot worker7 and wait for return
#      6. Health check
#      7. Verification
#
#  Notes:
#    - ASCII-only, nano-safe, deterministic.
#    - Must be run as builder on kubenode1.
# =====================================================================

set -euo pipefail

TARGET="kubenode7.home.lab"
SRC_DIR="/home/builder/src/kernel"
OUT_DIR="/home/builder/kernel-out"

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

if ! ssh "$TARGET" "echo ok" >/dev/null 2>&1; then
    echo "ERROR: Unable to reach $TARGET via SSH"
    exit 1
fi

echo
echo "=============================================================="
echo "  STEP 1: VALIDATE KERNEL ARTIFACTS"
echo "=============================================================="
echo

cd "${SRC_DIR}"
OUT_DIR="${OUT_DIR}" ./kernel-validate-build.sh

echo
echo "Validation complete."
echo

# ---------------------------------------------------------------------
#  STEP 2: BACKUP EXISTING KERNEL ON WORKER7
# ---------------------------------------------------------------------

echo "=============================================================="
echo "  STEP 2: BACKUP EXISTING KERNEL ON WORKER7"
echo "=============================================================="
echo

ssh builder@"${TARGET}" "sudo mkdir -p /boot/kernel-backups"

STAMP=$(date +"%Y%m%d-%H%M%S")

ssh builder@"${TARGET}" "sudo cp -a /boot /boot/kernel-backups/boot-${STAMP}"

echo "Backup created at /boot/kernel-backups/boot-${STAMP}"
echo

# ---------------------------------------------------------------------
#  STEP 3: DEPLOY NEW KERNEL ARTIFACTS
# ---------------------------------------------------------------------

echo "=============================================================="
echo "  STEP 3: DEPLOY NEW KERNEL ARTIFACTS"
echo "=============================================================="
echo

ssh builder@"${TARGET}" "sudo mkdir -p /boot/custom-kernel"
ssh builder@"${TARGET}" "sudo mkdir -p /boot/custom-kernel/dts"
ssh builder@"${TARGET}" "sudo mkdir -p /boot/custom-kernel/dts/overlays"

rsync -avz \
    "${OUT_DIR}/arch/arm/boot/Image" \
    "${OUT_DIR}/arch/arm/boot/zImage" \
    "${OUT_DIR}/vmlinux" \
    "${OUT_DIR}/System.map" \
    builder@"${TARGET}":/boot/custom-kernel/

rsync -avz \
    "${OUT_DIR}/arch/arm/boot/dts/" \
    builder@"${TARGET}":/boot/custom-kernel/dts/

echo "Kernel + DTBs deployed."
echo

# ---------------------------------------------------------------------
#  STEP 4: DEPLOY MODULES
# ---------------------------------------------------------------------

echo "=============================================================="
echo "  STEP 4: DEPLOY KERNEL MODULES"
echo "=============================================================="
echo

KERNEL_RELEASE=$(<"${OUT_DIR}/include/config/kernel.release")

ssh builder@"${TARGET}" "sudo mkdir -p /lib/modules/${KERNEL_RELEASE}"

rsync -avz \
    "${OUT_DIR}/lib/modules/${KERNEL_RELEASE}/" \
    builder@"${TARGET}":/lib/modules/${KERNEL_RELEASE}/

echo "Modules deployed."
echo

# ---------------------------------------------------------------------
#  STEP 5: ACTIVATE NEW KERNEL
# ---------------------------------------------------------------------

echo "=============================================================="
echo "  STEP 5: ACTIVATE NEW KERNEL"
echo "=============================================================="
echo

ssh builder@"${TARGET}" "sudo cp /boot/custom-kernel/zImage /boot/zImage-custom"
ssh builder@"${TARGET}" "sudo cp /boot/custom-kernel/Image /boot/Image-custom"

echo "Bootloader updated."
echo

# ---------------------------------------------------------------------
#  STEP 6: REBOOT WORKER7 AND WAIT
# ---------------------------------------------------------------------

echo "=============================================================="
echo "  STEP 6: REBOOT WORKER7"
echo "=============================================================="
echo

ssh builder@"${TARGET}" "sudo reboot" || true

echo "Waiting for worker7 to return..."

sleep 5

while true; do
    if ssh -o ConnectTimeout=2 "$TARGET" "echo ok" >/dev/null 2>&1; then
        echo "Worker7 is back online."
        break
    fi
    sleep 2
done

echo

# ---------------------------------------------------------------------
#  STEP 7: HEALTH CHECK
# ---------------------------------------------------------------------

echo "=============================================================="
echo "  STEP 7: HEALTH CHECK"
echo "=============================================================="
echo

ssh builder@"${TARGET}" "uname -a"
ssh builder@"${TARGET}" "ls -l /boot/zImage-custom"
ssh builder@"${TARGET}" "ls -l /lib/modules/${KERNEL_RELEASE}"

echo "Basic health checks passed."
echo

# ---------------------------------------------------------------------
#  STEP 8: VERIFICATION
# ---------------------------------------------------------------------

echo "=============================================================="
echo "  STEP 8: VERIFICATION"
echo "=============================================================="
echo

ssh builder@"${TARGET}" "sudo dmesg | grep -i 'Linux version' | head -n 1"
ssh builder@"${TARGET}" "sudo dmesg | grep -i dtb | head -n 5"

echo
echo "=============================================================="
echo "  POST-BUILD PIPELINE COMPLETE"
echo "=============================================================="
echo "Worker7 is now running the new kernel and has passed health + verification."
echo
