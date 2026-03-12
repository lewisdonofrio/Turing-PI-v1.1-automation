#!/usr/bin/env bash
set -euo pipefail

# ==============================================================
#  BUILDER-SIDE MODULE COMPLETENESS CHECK
#  Compares worker7's currently loaded modules against the
#  modules built in /home/builder/kernel-out.
#
#  Usage:
#      ./builder-compare-worker7-modules.sh worker7-hostname
#
# ==============================================================

if [[ $# -ne 1 ]]; then
    echo "Usage: $0 <worker7-hostname>"
    exit 1
fi

WORKER="$1"
OUT_DIR="/home/builder/kernel-out"

echo "=== BUILDER-SIDE MODULE COMPLETENESS CHECK ==="
echo "Worker node: $WORKER"
echo "OUT_DIR:     $OUT_DIR"
echo

# --------------------------------------------------------------
# STEP 1: Detect kernelrelease from OUT_DIR
# --------------------------------------------------------------
KREL_FILE="$OUT_DIR/include/config/kernel.release"
if [[ ! -f "$KREL_FILE" ]]; then
    echo "ERROR: kernel.release not found in $KREL_FILE"
    exit 1
fi

KREL=$(cat "$KREL_FILE")
MODDIR="$OUT_DIR/lib/modules/$KREL"

echo "Detected built kernelrelease: $KREL"
echo "Built modules directory:      $MODDIR"
echo

if [[ ! -d "$MODDIR" ]]; then
    echo "ERROR: Built modules directory missing: $MODDIR"
    exit 1
fi

# --------------------------------------------------------------
# STEP 2: Collect running modules from worker7
# --------------------------------------------------------------
echo "Collecting running modules from $WORKER ..."

ssh "$WORKER" "lsmod | awk 'NR>1 {print \$1}'" \
    > /tmp/worker7.running.modules

RUNNING_COUNT=$(wc -l < /tmp/worker7.running.modules)

echo "Worker7 is currently using $RUNNING_COUNT modules."
echo

# --------------------------------------------------------------
# STEP 3: Enumerate built modules in kernel-out
# --------------------------------------------------------------
echo "Enumerating built modules in $MODDIR ..."

find "$MODDIR" -type f \( -name "*.ko" -o -name "*.ko.xz" \) \
    | sed 's#.*/##' \
    | sed 's/.ko.xz$//' \
    | sed 's/.ko$//' \
    | sort \
    > /tmp/builder.built.modules

BUILT_COUNT=$(wc -l < /tmp/builder.built.modules)

echo "Built kernel contains $BUILT_COUNT modules."
echo

# --------------------------------------------------------------
# STEP 4: Compare sets
# --------------------------------------------------------------
echo "Comparing running modules vs built modules..."
echo

# Missing modules = in running list but not in built list
comm -23 /tmp/worker7.running.modules /tmp/builder.built.modules \
    > /tmp/missing.modules || true

MISSING_COUNT=$(wc -l < /tmp/missing.modules)

if [[ "$MISSING_COUNT" -eq 0 ]]; then
    echo "=== PASS: All running modules exist in the new kernel build ==="
else
    echo "=== WARNING: Missing modules detected ($MISSING_COUNT) ==="
    echo "These modules are currently loaded on worker7 but do not exist in the new build:"
    echo
    cat /tmp/missing.modules
    echo
    echo "This does NOT always mean failure — some modules become built-ins or renamed."
    echo "But you should review this list before deploying."
fi

echo
echo "=== MODULE COMPARISON COMPLETE ==="
