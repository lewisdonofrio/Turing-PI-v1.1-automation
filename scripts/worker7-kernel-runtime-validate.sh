#!/usr/bin/env bash
set -euo pipefail

EXPECTED_KREL="${1:-}"  # optional: pass expected kernelrelease

echo "=== WORKER7 KERNEL RUNTIME VALIDATOR ==="
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

KO_COUNT=$(find "$MODDIR" -type f -name "*.ko" -o -name "*.ko.xz" | wc -l)
if [[ "$KO_COUNT" -eq 0 ]]; then
    echo "ERROR: No modules found under $MODDIR"
    exit 1
fi

echo "Found $KO_COUNT modules under $MODDIR."

META_OK=true
for f in modules.dep modules.alias modules.order; do
    if [[ ! -f "$MODDIR/$f" ]]; then
        echo "ERROR: Missing module metadata: $MODDIR/$f"
        META_OK=false
    fi
done

if [[ "$META_OK" = false ]]; then
    exit 1
fi

# Try modprobe on a couple of common modules (best-effort)
echo
echo "Testing modprobe for a couple of modules (best effort)..."

TEST_MODULES=(ipv6 x_tables br_netfilter)
for m in "${TEST_MODULES[@]}"; do
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
echo "=== RUNTIME VALIDATION PASSED (within tested scope) ==="
