#!/bin/bash
# =============================================================================
# File: kernel-verify.sh
# Purpose: Full Raspberry Pi 3 / CM3+ kernel viability test.
#          Ensures the kernel image, DTBs, overlays, modules, built-ins,
#          and k3s-required netfilter stack are present and valid before
#          installation. Pure verifier: no system mutation.
# =============================================================================

set -euo pipefail

KERNEL_TREE="/home/builder/src/kernel"
ARCH="arm"
BOOT="/boot"

IMAGE="${KERNEL_TREE}/arch/${ARCH}/boot/zImage"
DTB_DIR="${KERNEL_TREE}/arch/${ARCH}/boot/dts/broadcom"
OVERLAY_DIR="${KERNEL_TREE}/arch/${ARCH}/boot/dts/overlays"

MAP="${KERNEL_TREE}/System.map"
SYMVERS="${KERNEL_TREE}/Module.symvers"

DTB_CM3="${DTB_DIR}/bcm2710-rpi-cm3.dtb"
DTB_CM3_IO="${DTB_DIR}/bcm2837-rpi-cm3-io3.dtb"

echo "=== kernel-verify.sh ==="
echo "Kernel tree: ${KERNEL_TREE}"
echo

fail() { echo "FAIL: $1"; exit 1; }
pass() { echo "OK: $1"; }

# -----------------------------------------------------------------------------
# 1. Kernel image validity
# -----------------------------------------------------------------------------
echo "[1] Checking kernel image..."
[[ -f "${IMAGE}" ]] || fail "Missing zImage"
[[ -s "${IMAGE}" ]] || fail "zImage is zero bytes"

FILE_TYPE=$(file -b "${IMAGE}")
echo "${FILE_TYPE}" | grep -qi "ARM boot executable zImage" \
    || fail "zImage does not appear to be a valid ARM boot image"

pass "Kernel image valid"

# -----------------------------------------------------------------------------
# 2. Required CM3+ DTBs
# -----------------------------------------------------------------------------
echo "[2] Checking CM3+ DTBs..."
[[ -f "${DTB_CM3}" ]] || fail "Missing bcm2710-rpi-cm3.dtb"
[[ -f "${DTB_CM3_IO}" ]] || fail "Missing bcm2837-rpi-cm3-io3.dtb"
[[ -s "${DTB_CM3}" ]] || fail "bcm2710-rpi-cm3.dtb is zero bytes"
[[ -s "${DTB_CM3_IO}" ]] || fail "bcm2837-rpi-cm3-io3.dtb is zero bytes"

pass "CM3+ DTBs OK"

# -----------------------------------------------------------------------------
# 3. DTB sanity
# -----------------------------------------------------------------------------
echo "[3] Checking DTB sanity..."
ZERO_DTB=$(find "${DTB_DIR}" -name "*.dtb" -size 0 -print || true)
[[ -z "${ZERO_DTB}" ]] || fail "Zero-byte DTBs found: ${ZERO_DTB}"

DTB_COUNT=$(find "${DTB_DIR}" -name "*.dtb" | wc -l)
[[ "${DTB_COUNT}" -gt 10 ]] || fail "Suspiciously low DTB count (${DTB_COUNT})"

pass "DTB sanity OK"

# -----------------------------------------------------------------------------
# 4. Overlays
# -----------------------------------------------------------------------------
echo "[4] Checking overlays..."
[[ -d "${OVERLAY_DIR}" ]] || fail "Missing overlays directory"

OVERLAY_COUNT=$(find "${OVERLAY_DIR}" -name "*.dtbo" | wc -l)
[[ "${OVERLAY_COUNT}" -gt 0 ]] || fail "No overlays found"

for o in vc4-kms-v3d.dtbo i2c1.dtbo spi0.dtbo mmc.dtbo; do
    if ! find "${OVERLAY_DIR}" -name "${o}" | grep -q .; then
        echo "WARN: Missing common overlay: ${o}"
    fi
done

pass "Overlays OK"

# -----------------------------------------------------------------------------
# 5. Kernel metadata
# -----------------------------------------------------------------------------
echo "[5] Checking kernel metadata..."
[[ -f "${MAP}" ]] || fail "Missing System.map"
[[ -f "${SYMVERS}" ]] || fail "Missing Module.symvers"
pass "Metadata OK"

# -----------------------------------------------------------------------------
# 6. Required modules in build tree
# -----------------------------------------------------------------------------
echo "[6] Checking required modules in build tree..."

declare -a NF_MODS=(
    nf_conntrack.ko
    nf_nat.ko
    iptable_filter.ko
    iptable_nat.ko
    xt_MASQUERADE.ko
    xt_conntrack.ko
    xt_comment.ko
)

declare -a FS_MODS=(ext4.ko vfat.ko nls_cp437.ko)
declare -a BLOCK_MODS=(sdhci.ko sdhci-iproc.ko mmc_block.ko)
declare -a PI_MODS=(bcm2835-thermal.ko bcm2835-mmc.ko vc4.ko)

for mod in "${NF_MODS[@]}" "${FS_MODS[@]}" "${BLOCK_MODS[@]}" "${PI_MODS[@]}"; do
    find "${KERNEL_TREE}" -name "${mod}" | grep -q . \
        || fail "Missing module: ${mod}"
done

pass "Required modules OK"

# -----------------------------------------------------------------------------
# 6b. Conntrack presence in System.map
# -----------------------------------------------------------------------------
echo "[6b] Checking conntrack presence in System.map..."
grep -qi "nf_conntrack" "${MAP}" || fail "Conntrack not present in kernel (System.map)"
pass "Conntrack present in kernel (System.map)"

# -----------------------------------------------------------------------------
# 7. Built-in Raspberry Pi drivers
# -----------------------------------------------------------------------------
echo "[7] Checking built-in Pi drivers..."

declare -a BUILTIN_PI=(
    bcm2835_dma
    bcm2835_mailbox
    bcm2835_rng
    bcm2835_wdt
    bcm2835_power
    bcm2835_gpiomem
)

for sym in "${BUILTIN_PI[@]}"; do
    grep -q "${sym}" "${MAP}" || fail "Missing built-in driver: ${sym}"
done

pass "Built-in Pi drivers OK"

# -----------------------------------------------------------------------------
# 8. Module count sanity
# -----------------------------------------------------------------------------
echo "[8] Checking module count..."
MOD_COUNT=$(find "${KERNEL_TREE}" -name "*.ko" | wc -l)
[[ "${MOD_COUNT}" -gt 200 ]] || fail "Suspiciously low module count (${MOD_COUNT})"
pass "Module count OK (${MOD_COUNT})"

# -----------------------------------------------------------------------------
# 9. Kernelrelease consistency
# -----------------------------------------------------------------------------
echo "[9] Checking kernelrelease..."
KR=$(make -sC "${KERNEL_TREE}" kernelrelease)
[[ -n "${KR}" ]] || fail "kernelrelease empty"
pass "kernelrelease = ${KR}"

# -----------------------------------------------------------------------------
# 10. Timestamp sanity
# -----------------------------------------------------------------------------
echo "[10] Checking timestamp sanity..."
IMG_TS=$(stat -c %Y "${IMAGE}")
DTB_TS=$(stat -c %Y "${DTB_CM3}")

[[ "${IMG_TS}" -ge "${DTB_TS}" ]] || fail "zImage older than CM3 DTB"
pass "Timestamps OK"

echo
echo "==============================================="
echo "Kernel verification PASSED — kernel is viable."
echo "==============================================="
