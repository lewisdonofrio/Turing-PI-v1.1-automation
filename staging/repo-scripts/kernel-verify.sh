#!/bin/bash
# =============================================================================
# File: /home/builder/scripts/kernel-verify.sh
# Purpose: Full Raspberry Pi 3 kernel viability test.
#          Ensures the kernel image, DTBs, modules, and k3s-required netfilter
#          stack are present and valid before installation.
# =============================================================================

set -euo pipefail

KERNEL_TREE="/home/builder/src/kernel"
ARCH="arm"
BOOT="/boot"
REQUIRED_DTB_PREFIX="bcm2710-rpi-3"
REQUIRED_IMAGE="${KERNEL_TREE}/arch/${ARCH}/boot/zImage"
REQUIRED_DTBS="${KERNEL_TREE}/arch/${ARCH}/boot/dts"
REQUIRED_OVERLAYS="${REQUIRED_DTBS}/overlays"
REQUIRED_MAP="${KERNEL_TREE}/System.map"
REQUIRED_SYMVERS="${KERNEL_TREE}/Module.symvers"

echo "=== kernel-verify.sh ==="
echo "Kernel tree: ${KERNEL_TREE}"
echo

fail() {
    echo "FAIL: $1"
    exit 1
}

pass() {
    echo "OK: $1"
}

# -----------------------------------------------------------------------------
# 1. Kernel image
# -----------------------------------------------------------------------------
echo "[1] Checking kernel image..."
[[ -f "${REQUIRED_IMAGE}" ]] || fail "Missing zImage"
pass "Kernel image exists"

# -----------------------------------------------------------------------------
# 2. DTBs
# -----------------------------------------------------------------------------
echo "[2] Checking DTBs..."
DTB_COUNT=$(ls "${REQUIRED_DTBS}"/*.dtb 2>/dev/null | wc -l)
[[ "${DTB_COUNT}" -gt 0 ]] || fail "No DTBs found"

# Pi 3 specific DTB
ls "${REQUIRED_DTBS}/${REQUIRED_DTB_PREFIX}"*.dtb >/dev/null 2>&1 \
    || fail "Missing Raspberry Pi 3 DTB (${REQUIRED_DTB_PREFIX}*.dtb)"

pass "DTBs OK"

# -----------------------------------------------------------------------------
# 3. Overlays
# -----------------------------------------------------------------------------
echo "[3] Checking overlays..."
OVERLAY_COUNT=$(ls "${REQUIRED_OVERLAYS}"/*.dtbo 2>/dev/null | wc -l)
[[ "${OVERLAY_COUNT}" -gt 0 ]] || fail "No DTBO overlays found"
pass "Overlays OK"

# -----------------------------------------------------------------------------
# 4. System.map + Module.symvers
# -----------------------------------------------------------------------------
echo "[4] Checking kernel metadata..."
[[ -f "${REQUIRED_MAP}" ]] || fail "Missing System.map"
[[ -f "${REQUIRED_SYMVERS}" ]] || fail "Missing Module.symvers"
pass "Metadata OK"

# -----------------------------------------------------------------------------
# 5. Required netfilter modules (k3s-critical)
# -----------------------------------------------------------------------------
echo "[5] Checking netfilter modules..."
declare -a NF_MODS=(
    "nf_conntrack.ko"
    "nf_conntrack_proto_tcp.ko"
    "nf_conntrack_proto_udp.ko"
    "nf_nat.ko"
    "nf_nat_ipv4.ko"
    "iptable_filter.ko"
    "iptable_nat.ko"
    "xt_MASQUERADE.ko"
    "xt_conntrack.ko"
    "xt_comment.ko"
)

for mod in "${NF_MODS[@]}"; do
    find "${KERNEL_TREE}" -name "${mod}" | grep -q . \
        || fail "Missing netfilter module: ${mod}"
done
pass "Netfilter stack OK"

# -----------------------------------------------------------------------------
# 6. Required block + filesystem drivers
# -----------------------------------------------------------------------------
echo "[6] Checking block/filesystem drivers..."
declare -a FS_MODS=(
    "ext4.ko"
    "vfat.ko"
    "nls_cp437.ko"
)

declare -a BLOCK_MODS=(
    "sdhci.ko"
    "sdhci-iproc.ko"
    "mmc_block.ko"
)

for mod in "${FS_MODS[@]}" "${BLOCK_MODS[@]}"; do
    find "${KERNEL_TREE}" -name "${mod}" | grep -q . \
        || fail "Missing filesystem/block module: ${mod}"
done
pass "Filesystem + block drivers OK"

# -----------------------------------------------------------------------------
# 7. Raspberry Pi firmware + thermal drivers
# -----------------------------------------------------------------------------
echo "[7] Checking Raspberry Pi firmware drivers..."
declare -a PI_MODS=(
    "bcm2835-thermal.ko"
    "bcm2835-mmc.ko"
    "vc4.ko"
)

for mod in "${PI_MODS[@]}"; do
    find "${KERNEL_TREE}" -name "${mod}" | grep -q . \
        || fail "Missing Raspberry Pi driver: ${mod}"
done
pass "Raspberry Pi drivers OK"

# -----------------------------------------------------------------------------
# 8. Module dependency files
# -----------------------------------------------------------------------------
echo "[8] Checking module dependency files..."
MOD_DIR="/lib/modules/$(make -sC ${KERNEL_TREE} kernelrelease 2>/dev/null || echo unknown)"

[[ -d "${MOD_DIR}" ]] || echo "NOTE: modules not yet installed; skipping dep checks"

if [[ -d "${MOD_DIR}" ]]; then
    [[ -f "${MOD_DIR}/modules.dep" ]] || fail "Missing modules.dep"
    [[ -f "${MOD_DIR}/modules.alias" ]] || fail "Missing modules.alias"
    pass "Module dependency files OK"
else
    echo "Skipping module dep checks (modules not installed yet)"
fi

# -----------------------------------------------------------------------------
# 9. Kernelrelease consistency
# -----------------------------------------------------------------------------
echo "[9] Checking kernelrelease..."
KR=$(make -sC "${KERNEL_TREE}" kernelrelease)
[[ -n "${KR}" ]] || fail "kernelrelease empty"
pass "kernelrelease = ${KR}"

# -----------------------------------------------------------------------------
# 10. DTB sanity
# -----------------------------------------------------------------------------
echo "[10] Checking DTB sanity..."
grep -R "bcm2710" "${REQUIRED_DTBS}" >/dev/null 2>&1 \
    || fail "DTBs missing bcm2710 references"
pass "DTB sanity OK"

# -----------------------------------------------------------------------------
# 11. Module count sanity
# -----------------------------------------------------------------------------
echo "[11] Checking module count..."
MOD_COUNT=$(find "${KERNEL_TREE}" -name "*.ko" | wc -l)
[[ "${MOD_COUNT}" -gt 200 ]] || fail "Suspiciously low module count (${MOD_COUNT})"
pass "Module count OK (${MOD_COUNT})"

echo
echo "==============================================="
echo "Kernel verification PASSED — kernel is viable."
echo "==============================================="
