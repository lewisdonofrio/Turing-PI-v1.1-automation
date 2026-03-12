#!/usr/bin/env bash
set -euo pipefail

EXPECTED_KREL="${1:-}"

echo "=============================================================="
echo "  WORKER7 POST-DEPLOY RUNTIME VALIDATOR"
echo "=============================================================="
echo

RUNNING_KREL=$(uname -r)
echo "Running kernel: $RUNNING_KREL"

if [[ -n "$EXPECTED_KREL" && "$EXPECTED_KREL" != "$RUNNING_KREL" ]]; then
    echo "ERROR: Expected kernel '$EXPECTED_KREL' but running '$RUNNING_KREL'"
    exit 1
fi

MODDIR="/lib/modules/$RUNNING_KREL"
if [[ ! -d "$MODDIR" ]]; then
    echo "ERROR: Modules directory missing: $MODDIR"
    exit 1
fi

echo "Modules directory exists."
echo

# --------------------------------------------------------------
# STEP 1: Check critical features (overlay, fuse, br_netfilter)
# --------------------------------------------------------------
echo "Checking critical kernel features..."

check_builtin_or_module() {
    local symbol="$1"
    local desc="$2"

    if grep -q "$symbol" /proc/kallsyms 2>/dev/null; then
        printf "  [PASS] %-20s (%s built-in)\n" "$symbol" "$desc"
        return 0
    fi

    if modinfo "$symbol" &>/dev/null; then
        printf "  [PASS] %-20s (%s as module)\n" "$symbol" "$desc"
        return 0
    fi

    printf "  [FAIL] %-20s (%s missing!)\n" "$symbol" "$desc"
    return 1
}

FAIL=0

check_builtin_or_module "overlay"      "overlay filesystem" || FAIL=1
check_builtin_or_module "fuse"         "FUSE filesystem" || FAIL=1
check_builtin_or_module "br_netfilter" "bridge netfilter" || FAIL=1

echo

# --------------------------------------------------------------
# STEP 2: Try loading a few modules (best effort)
# --------------------------------------------------------------
echo "Testing modprobe for common modules..."

for m in ipv6 x_tables nf_conntrack; do
    if modinfo "$m" &>/dev/null; then
        echo "  modprobe $m ..."
        if sudo modprobe "$m"; then
            echo "    OK"
        else
            echo "    FAILED (non-fatal)"
        fi
    fi
done

echo

# --------------------------------------------------------------
# STEP 3: OverlayFS mount test
# --------------------------------------------------------------
echo "Testing overlayfs mount..."

TMPDIR=$(mktemp -d)
mkdir -p "$TMPDIR"/{lower,upper,work,merged}

if sudo mount -t overlay overlay \
    -o lowerdir="$TMPDIR/lower",upperdir="$TMPDIR/upper",workdir="$TMPDIR/work" \
    "$TMPDIR/merged" 2>/dev/null; then
    echo "  [PASS] overlayfs mount works"
    sudo umount "$TMPDIR/merged"
else
    echo "  [FAIL] overlayfs mount failed"
    FAIL=1
fi

rm -rf "$TMPDIR"
echo

# --------------------------------------------------------------
# STEP 4: FUSE test (best effort)
# --------------------------------------------------------------
echo "Testing FUSE availability..."

if grep -q fuse /proc/filesystems; then
    echo "  [PASS] FUSE filesystem supported"
else
    echo "  [FAIL] FUSE filesystem missing"
    FAIL=1
fi

echo

# --------------------------------------------------------------
# STEP 5: Check systemd health
# --------------------------------------------------------------
echo "Checking systemd health..."

if systemctl is-system-running --quiet; then
    echo "  [PASS] systemd reports healthy"
else
    echo "  [WARN] systemd reports degraded state"
    systemctl --failed || true
fi

echo

# --------------------------------------------------------------
# STEP 6: Check dmesg for kernel errors
# --------------------------------------------------------------
echo "Scanning dmesg for kernel errors..."

if dmesg | grep -E "BUG:|panic|tainted|Call Trace" >/dev/null; then
    echo "  [WARN] Kernel warnings/errors detected in dmesg"
else
    echo "  [PASS] No kernel errors detected"
fi

echo

# --------------------------------------------------------------
# FINAL RESULT
# --------------------------------------------------------------
if [[ "$FAIL" -eq 0 ]]; then
    echo "=============================================================="
    echo "  RUNTIME VALIDATION PASSED — worker7 is healthy"
    echo "=============================================================="
    exit 0
else
    echo "=============================================================="
    echo "  RUNTIME VALIDATION FAILED — review issues above"
    echo "=============================================================="
    exit 1
fi
