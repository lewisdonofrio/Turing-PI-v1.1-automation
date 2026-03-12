#!/usr/bin/env bash
set -u -o pipefail

SCRIPT_NAME="$(basename "$0")"
TAR="${TAR:-/usr/bin/tar}"

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

pass() {
    echo "PASS: $*"
}

usage() {
    cat <<EOF
Usage:
  ${SCRIPT_NAME} --pre <kernel_tarball> --tree <kernel_tree>

This performs a host-side validation ensuring the tarball contains
all required files from the kernel tree and that structure, file types,
and critical artifacts are correct before installation.
EOF
    exit 1
}

# --- argument parsing ---------------------------------------------------------

TARBALL=""
KERNEL_TREE=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --pre)
            TARBALL="$2"
            shift 2
            ;;
        --tree)
            KERNEL_TREE="$2"
            shift 2
            ;;
        *)
            usage
            ;;
    esac
done

[[ -n "${TARBALL}" ]] || usage
[[ -n "${KERNEL_TREE}" ]] || usage

[[ -f "${TARBALL}" ]] || fail "Tarball not found: ${TARBALL}"
[[ -d "${KERNEL_TREE}" ]] || fail "Kernel tree not found: ${KERNEL_TREE}"

echo "=== kernel-verify.sh (host-side tarball/tree validation) ==="
echo "Tarball: ${TARBALL}"
echo "Tree:    ${KERNEL_TREE}"

# --- load tarball listing safely ---------------------------------------------

echo "[0] Reading tarball listing..."
TARLIST="$(set +o pipefail; ${TAR} -tzf "${TARBALL}")" || fail "Unable to read tarball"
echo "$TARLIST" | head -20

# --- required top-level files -------------------------------------------------

echo "[1] Checking required top-level files..."

REQUIRED_TOP=(
    "boot/kernel7.img"
    "kernelrelease.txt"
)

for f in "${REQUIRED_TOP[@]}"; do
    echo "  - $f"
    echo "$TARLIST" | grep -qx "./$f" || fail "Missing required file: $f"
done

pass "All required top-level files present"

# --- verify kernelrelease.txt matches tree -----------------------------------

echo "[2] Checking kernelrelease.txt consistency..."

TREE_REL="${KERNEL_TREE}/include/config/kernel.release"
[[ -f "$TREE_REL" ]] || fail "Missing kernel.release in tree"

TREE_REL_VAL="$(cat "$TREE_REL")"

TAR_REL_VAL="$(
    set +o pipefail
    ${TAR} -xOf "${TARBALL}" kernelrelease.txt 2>/dev/null
)"

[[ "$TREE_REL_VAL" == "$TAR_REL_VAL" ]] || fail "kernelrelease mismatch: tree='$TREE_REL_VAL' tar='$TAR_REL_VAL'"

pass "kernelrelease.txt matches"

# --- verify modules exist and match structure --------------------------------

echo "[3] Checking modules directory..."

TREE_MOD_DIR="$(find "${KERNEL_TREE}/" -type f -name '*.ko' | wc -l)"
[[ "$TREE_MOD_DIR" -gt 0 ]] || fail "No modules in tree"

TAR_MOD_DIR="$(echo "$TARLIST" | grep -c '^./lib/modules/.*/kernel/.*\.ko')"
[[ "$TAR_MOD_DIR" -gt 0 ]] || fail "No modules in tarball"

pass "Modules present in both tree and tarball"

# --- verify DTBs --------------------------------------------------------------

echo "[4] Checking DTBs..."

TREE_DTBS="$(find "${KERNEL_TREE}/arch/arm/boot/dts" -type f -name '*.dtb' | wc -l)"
[[ "$TREE_DTBS" -gt 0 ]] || fail "No DTBs in tree"

TAR_DTBS="$(echo "$TARLIST" | grep -c '^./boot/dtbs/.*\.dtb')"
[[ "$TAR_DTBS" -gt 0 ]] || fail "No DTBs in tarball"

pass "DTBs present in both tree and tarball"

# --- verify no forbidden files ------------------------------------------------

echo "[5] Checking for forbidden files..."

FORBIDDEN_PATTERNS=(
    '\.cmd$'
    '\.tmp$'
    '\.o$'
    '\.d$'
)

for pat in "${FORBIDDEN_PATTERNS[@]}"; do
    if echo "$TARLIST" | grep -Eq "$pat"; then
        fail "Forbidden file pattern found in tarball: $pat"
    fi
done

pass "No forbidden files found"

# --- verify ASCII-safe filenames ---------------------------------------------

echo "[6] Checking ASCII-safe filenames..."

if echo "$TARLIST" | LC_ALL=C grep -Pv '^[\x00-\x7F]+$' >/dev/null; then
    fail "Non-ASCII filenames detected"
fi

pass "All filenames ASCII-safe"

# --- verify no empty files ----------------------------------------------------

echo "[7] Checking for empty files..."

EMPTY_COUNT="$(
    set +o pipefail
    ${TAR} -tvzf "${TARBALL}" | awk '$3 == 0 {print}' | wc -l
)"

[[ "$EMPTY_COUNT" -eq 0 ]] || fail "Empty files detected in tarball"

pass "No empty files"

# --- final verdict ------------------------------------------------------------

echo "=== Tarball/tree validation PASSED ==="
exit 0
