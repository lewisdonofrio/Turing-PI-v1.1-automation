#!/usr/bin/env bash

# =============================================================================
# kernel-verify.sh
#
# Modes:
#   --pre <tarball>
#       Validate a packaged kernel tarball for Raspberry Pi CM3:
#         - boot/kernel7.img present
#         - lib/modules/<release> present
#         - DTBs and overlays present
#         - at least one .ko module
#         - optional kernelrelease.txt consistency
#
#   (no args)
#       Validate a kernel *tree* on disk:
#         - boot/kernel7.img present and sane
#         - required modules present in build tree
#         - modules tree on root FS looks sane
#         - CM3 DTB present and timestamp not newer than kernel7.img
#         - DTBs/overlays trees populated
#
# Environment / defaults:
#   KERNEL_TREE (default: /home/builder/src/kernel)
#   ARCH        (default: arm)
#
# This version avoids `set -e` and uses explicit conditional checks so it is
# safe to embed inside higher-level scripts that use `set -e`.
# =============================================================================

set -u -o pipefail

SCRIPT_NAME="$(basename "$0")"

# -----------------------------------------------------------------------------
# Helpers
# -----------------------------------------------------------------------------
fail() {
    echo "FAIL: $*" >&2
    exit 1
}

pass() {
    echo "PASS: $*"
}

info() {
    echo "INFO: $*"
}

usage() {
    cat <<EOF
Usage:
  ${SCRIPT_NAME} --pre <kernel-tarball>
  ${SCRIPT_NAME}

Description:
  --pre <tarball>
      Validate contents of a kernel tarball for Raspberry Pi CM3.
      Checks for boot/kernel7.img, modules, DTBs, overlays, and
      kernelrelease.txt consistency if present.

  (no args)
      Validate the kernel tree on disk pointed to by KERNEL_TREE.
      Checks boot/kernel7.img, required modules in the tree,
      /lib/modules layout, and CM3 DTB timestamp sanity.

Environment:
  KERNEL_TREE   Kernel source/install tree (default: /home/builder/src/kernel)
  ARCH          Target architecture (default: arm)
EOF
    exit 1
}

# -----------------------------------------------------------------------------
# Argument parsing
# -----------------------------------------------------------------------------
MODE="tree"
TARBALL=""

if [[ $# -gt 0 ]]; then
    case "$1" in
        --pre)
            [[ $# -eq 2 ]] || usage
            MODE="pre"
            TARBALL="$2"
            ;;
        -h|--help)
            usage
            ;;
        *)
            usage
            ;;
    esac
fi

# -----------------------------------------------------------------------------
# Common defaults
# -----------------------------------------------------------------------------
KERNEL_TREE="${KERNEL_TREE:-/home/builder/src/kernel}"
ARCH="${ARCH:-arm}"

# =============================================================================
# Mode: --pre <tarball> (tarball preflight validation)
# =============================================================================
if [[ "${MODE}" == "pre" ]]; then
    echo "=== ${SCRIPT_NAME} (preflight) ==="
    echo "Tarball: ${TARBALL}"

    # --- Basic tarball existence/size ----------------------------------------
    if [[ ! -f "${TARBALL}" ]]; then
        fail "Tarball not found: ${TARBALL}"
    fi

    if [[ ! -s "${TARBALL}" ]]; then
        fail "Tarball is zero bytes: ${TARBALL}"
    fi

    # --- 0. Quick listing sanity (no extraction) -----------------------------
    info "[0] Listing tarball (first few entries)..."

    # Validate tarball is readable
    if ! tar -tzf "${TARBALL}" >/dev/null 2>&1; then
        fail "Unable to list tarball contents (corrupt or unreadable)"
    fi

    # Then preview first 20 lines without SIGPIPE surprises
    if ! tar -tzf "${TARBALL}" | head -20; then
        fail "Failed to preview tarball contents"
    fi

    # --- 1. Kernel image presence: boot/kernel7.img --------------------------
    echo "[1] Checking kernel image in tarball..."
    if ! tar -tzf "${TARBALL}" | grep -Eq '^(./)?boot/kernel7\.img$'; then
        fail "Missing boot/kernel7.img in tarball"
    fi
    pass "boot/kernel7.img present in tarball"

    # --- 2. kernelrelease.txt (optional but preferred) -----------------------
    echo "[2] Checking kernelrelease.txt (if present)..."
    RELEASE=""
    if tar -tzf "${TARBALL}" | grep -q '^kernelrelease\.txt$'; then
        # Extract content of kernelrelease.txt
        RELEASE="$(tar -xOf "${TARBALL}" kernelrelease.txt 2>/dev/null || true)"
        if [[ -z "${RELEASE}" ]]; then
            fail "kernelrelease.txt present but empty or unreadable"
        fi
        info "kernelrelease.txt reports: ${RELEASE}"
    else
        info "kernelrelease.txt not present; will infer modules directory"
    fi

    # --- 3. Modules tree presence in tarball ---------------------------------
    echo "[3] Checking modules directory in tarball..."
    if [[ -n "${RELEASE}" ]]; then
        if ! tar -tzf "${TARBALL}" | grep -q "^lib/modules/${RELEASE}/"; then
            fail "Missing lib/modules/${RELEASE}/ in tarball"
        fi
        pass "lib/modules/${RELEASE}/ present in tarball"
    else
        MOD_DIRS="$(tar -tzf "${TARBALL}" | grep '^lib/modules/[^/]\\+/$' || true)"
        if [[ -z "${MOD_DIRS}" ]]; then
            fail "No lib/modules/<release>/ directories found in tarball"
        fi
        info "Found modules directories:"
        echo "${MOD_DIRS}"
        pass "Modules directory present in tarball"
    fi

    # --- 4. DTBs and overlays presence (sanity) ------------------------------
    echo "[4] Checking DTBs and overlays presence in tarball..."
    if ! tar -tzf "${TARBALL}" | grep -q '^boot/dtbs/'; then
        fail "Missing boot/dtbs/ in tarball"
    fi
    if ! tar -tzf "${TARBALL}" | grep -q '^boot/overlays/'; then
        fail "Missing boot/overlays/ in tarball"
    fi
    pass "DTBs and overlays trees present in tarball"

    # --- 5. At least one .ko module -----------------------------------------
    echo "[5] Checking for at least one module (.ko) in tarball..."
    if ! tar -tzf "${TARBALL}" | grep -q '\.ko$'; then
        fail "No .ko modules found in tarball under lib/modules"
    fi
    pass "At least one .ko module present in tarball"

    echo "=== Preflight tarball validation PASSED ==="
    exit 0
fi

# =============================================================================
# Mode: tree (on-disk kernel tree validation)
# =============================================================================

echo "=== ${SCRIPT_NAME} (tree) ==="
echo "Kernel tree: ${KERNEL_TREE}"
echo "ARCH: ${ARCH}"

if [[ ! -d "${KERNEL_TREE}" ]]; then
    fail "Kernel tree does not exist: ${KERNEL_TREE}"
fi

# -----------------------------------------------------------------------------
# 1. Kernel image validity (boot/kernel7.img)
# -----------------------------------------------------------------------------
echo "[1] Checking kernel image..."
IMAGE="${KERNEL_TREE}/boot/kernel7.img"

if [[ ! -f "${IMAGE}" ]]; then
    fail "Missing kernel7.img in kernel tree: ${IMAGE}"
fi

if [[ ! -s "${IMAGE}" ]]; then
    fail "kernel7.img is zero bytes: ${IMAGE}"
fi

if ! FILE_TYPE="$(file -b "${IMAGE}" 2>/dev/null)"; then
    fail "file(1) failed on kernel7.img: ${IMAGE}"
fi

echo "INFO: file(1) reports: ${FILE_TYPE}"

echo "${FILE_TYPE}" | grep -qi "ARM boot executable" || \
    fail "kernel7.img does not appear to be a valid ARM boot image"

pass "Kernel image valid"

# -----------------------------------------------------------------------------
# 2. Modules tree on root filesystem
# -----------------------------------------------------------------------------
echo "[2] Checking modules tree on /lib/modules..."

RELEASE_FILE="${KERNEL_TREE}/kernelrelease.txt"
RELEASE=""

if [[ -f "${RELEASE_FILE}" ]]; then
    RELEASE="$(<"${RELEASE_FILE}")"
    info "kernelrelease.txt reports: ${RELEASE}"
else
    info "kernelrelease.txt not found in tree; attempting to discover modules release"
fi

MODULES_BASE="/lib/modules"

if [[ -n "${RELEASE}" ]]; then
    MODULES_DIR="${MODULES_BASE}/${RELEASE}"
    if [[ ! -d "${MODULES_DIR}" ]]; then
        fail "Modules directory missing: ${MODULES_DIR}"
    fi
    pass "Modules directory present: ${MODULES_DIR}"
else
    MOD_DIRS_ON_DISK="$(find "${MODULES_BASE}" -maxdepth 1 -mindepth 1 -type d 2>/dev/null || true)"
    if [[ -z "${MOD_DIRS_ON_DISK}" ]]; then
        fail "No modules directories found under ${MODULES_BASE}"
    fi
    info "Found modules directories:"
    echo "${MOD_DIRS_ON_DISK}"
    pass "Modules directory exists under ${MODULES_BASE}"
fi

# -----------------------------------------------------------------------------
# 3. CM3 DTB presence and timestamp sanity
# -----------------------------------------------------------------------------
echo "[3] Checking CM3 DTB presence and timestamp sanity..."

CM3_DTB="${KERNEL_TREE}/boot/dtbs/broadcom/bcm2710-rpi-cm3.dtb"

if [[ ! -f "${CM3_DTB}" ]]; then
    fail "CM3 DTB not found at expected path: ${CM3_DTB}"
fi

if ! IMG_TS="$(stat -c '%Y' "${IMAGE}" 2>/dev/null)"; then
    fail "Failed to stat kernel7.img: ${IMAGE}"
fi

if ! DTB_TS="$(stat -c '%Y' "${CM3_DTB}" 2>/dev/null)"; then
    fail "Failed to stat CM3 DTB: ${CM3_DTB}"
fi

info "kernel7.img mtime: ${IMG_TS}"
info "CM3 DTB mtime: ${DTB_TS}"

if [[ "${IMG_TS}" -lt "${DTB_TS}" ]]; then
    fail "kernel7.img older than CM3 DTB (DTB newer than kernel image)"
fi

pass "CM3 DTB present and timestamp sane relative to kernel7.img"

# -----------------------------------------------------------------------------
# 4. DTBs / overlays presence in kernel tree
# -----------------------------------------------------------------------------
echo "[4] Checking DTBs and overlays trees in kernel tree..."

TREE_DTB_DIR="${KERNEL_TREE}/boot/dtbs"
TREE_OVL_DIR="${KERNEL_TREE}/boot/overlays"

if [[ ! -d "${TREE_DTB_DIR}" ]]; then
    fail "DTBs directory missing in tree: ${TREE_DTB_DIR}"
fi

if [[ ! -d "${TREE_OVL_DIR}" ]]; then
    fail "Overlays directory missing in tree: ${TREE_OVL_DIR}"
fi

DTB_COUNT="$(find "${TREE_DTB_DIR}" -type f -name '*.dtb' 2>/dev/null | wc -l || true)"
OVL_COUNT="$(find "${TREE_OVL_DIR}" -type f -name '*.dtbo' 2>/dev/null | wc -l || true)"

info "DTB count: ${DTB_COUNT}"
info "Overlay count: ${OVL_COUNT}"

if [[ "${DTB_COUNT}" -le 0 ]]; then
    fail "No .dtb files found under ${TREE_DTB_DIR}"
fi

if [[ "${OVL_COUNT}" -le 0 ]]; then
    fail "No .dtbo files found under ${TREE_OVL_DIR}"
fi

pass "DTBs and overlays trees present and populated in kernel tree"

# -----------------------------------------------------------------------------
# 5. Required modules in build tree
# -----------------------------------------------------------------------------
echo "[5] Checking required modules in build tree..."

declare -a NF_MODS=(
    nf_conntrack.ko
    nf_nat.ko
    iptable_filter.ko
    iptable_nat.ko
    xt_MASQUERADE.ko
    xt_conntrack.ko
    xt_comment.ko
)

declare -a FS_MODS=(
    ext4.ko
    vfat.ko
    nls_cp437.ko
)

declare -a BLOCK_MODS=(
    sdhci.ko
    sdhci-iproc.ko
    mmc_block.ko
)

declare -a PI_MODS=(
    bcm2835-thermal.ko
    bcm2835-mmc.ko
    vc4.ko
)

for mod in "${NF_MODS[@]}" "${FS_MODS[@]}" "${BLOCK_MODS[@]}" "${PI_MODS[@]}"; do
    if ! find "${KERNEL_TREE}" -name "${mod}" 2>/dev/null | grep -q .; then
        fail "Missing module in build tree: ${mod}"
    fi
done

pass "Required modules OK in build tree"

# -----------------------------------------------------------------------------
# Done
# -----------------------------------------------------------------------------
echo "=== Kernel tree validation PASSED ==="
exit 0
