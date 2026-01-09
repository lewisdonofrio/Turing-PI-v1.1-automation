#!/usr/bin/env bash
set -euo pipefail

echo "==============================================================="
echo " PUMP GROUND TEST - Doctrine-Aligned Validation Suite"
echo "==============================================================="

# ---------------------------------------------------------------------
# Phase 1: PATH + toolchain sanity
# ---------------------------------------------------------------------
echo "[1/7] Validating PATH and toolchain..."

if ! command -v pump >/dev/null 2>&1; then
    echo "ERROR: pump not found in PATH"
    exit 1
fi

if ! command -v distcc >/dev/null 2>&1; then
    echo "ERROR: distcc not found in PATH"
    exit 1
fi

if ! command -v gcc >/dev/null 2>&1; then
    echo "ERROR: gcc not found in PATH"
    exit 1
fi

echo "OK: PATH and toolchain present"


# ---------------------------------------------------------------------
# Phase 2: pump wrapper validation
# ---------------------------------------------------------------------
echo "[2/7] Validating pump wrapper..."

if ! pump --version >/dev/null 2>&1; then
    echo "ERROR: pump wrapper not functional"
    exit 1
fi

echo "OK: pump wrapper functional"


# ---------------------------------------------------------------------
# Phase 3: include-server validation
# ---------------------------------------------------------------------
echo "[3/7] Validating include-server startup..."

TMPDIR=$(mktemp -d)
TESTFILE="${TMPDIR}/test.c"

cat > "${TESTFILE}" <<EOF
int main(void) { return 0; }
EOF

if ! pump gcc -c "${TESTFILE}" -o "${TMPDIR}/test.o" >/dev/null 2>&1; then
    echo "ERROR: include-server failed to preprocess test file"
    exit 1
fi

echo "OK: include-server operational"


# ---------------------------------------------------------------------
# Phase 4: Remote preprocessing (DOTI) validation
# ---------------------------------------------------------------------
echo "[4/7] Validating remote preprocessing (DOTI)..."

LOGFILE="/home/builder/build-logs/distcc.log"
touch "${LOGFILE}"

# Clear old DOTI entries
sed -i '/DOTI/d' "${LOGFILE}"

pump gcc -c "${TESTFILE}" -o "${TMPDIR}/test2.o" >/dev/null 2>&1

if ! grep -q DOTI "${LOGFILE}"; then
    echo "ERROR: No DOTI tokens detected — remote preprocessing not occurring"
    exit 1
fi

echo "OK: DOTI detected — remote preprocessing functional"


# ---------------------------------------------------------------------
# Phase 5: Worker enumeration
# ---------------------------------------------------------------------
echo "[5/7] Validating worker availability..."

WORKERS=$(distcc -j | grep -v localhost || true)

if [[ -z "${WORKERS}" ]]; then
    echo "ERROR: No remote workers detected by distcc"
    exit 1
fi

echo "OK: Workers detected:"
echo "${WORKERS}"


# ---------------------------------------------------------------------
# Phase 6 (NEW): Effective CC Validation
# ---------------------------------------------------------------------
echo "[6/7] Validating effective CC for kernel build..."

KERNEL_DIR="/home/builder/linux"
if [[ ! -d "${KERNEL_DIR}" ]]; then
    echo "ERROR: Kernel directory not found at ${KERNEL_DIR}"
    exit 1
fi

cd "${KERNEL_DIR}"

# Run a tiny kernel-style compile and capture the actual CC invocation
OUT=$(make -s ARCH=arm V=1 kernel/bounds.s CC="pump gcc" 2>&1 | head -n 1 || true)

if ! echo "${OUT}" | grep -q "pump gcc"; then
    echo "ERROR: Kernel Makefile is NOT honoring CC=\"pump gcc\""
    echo "       Effective CC is:"
    echo "       ${OUT}"
    echo ""
    echo "This would cause a pure-local build and OOM the builder."
    exit 1
fi

echo "OK: Kernel Makefile honors CC=\"pump gcc\""


# ---------------------------------------------------------------------
# Phase 7: Final readiness verdict
# ---------------------------------------------------------------------
echo "[7/7] All pump-mode ground checks PASSED"
echo "==============================================================="
echo " Pump-mode is READY for distributed kernel build"
echo "==============================================================="

exit 0
