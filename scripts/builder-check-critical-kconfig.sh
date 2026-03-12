#!/usr/bin/env bash
set -euo pipefail

# ==============================================================
#  CRITICAL KCONFIG CHECKER (builder-side)
#  Validates that the built kernel has the essential features:
#    - BRIDGE_NETFILTER (for Kubernetes networking)
#    - OVERLAY_FS       (for container runtimes)
#    - FUSE_FS          (for user-space filesystems)
#
#  Usage:
#      ./builder-check-critical-kconfig.sh
#
# ==============================================================

OUT_DIR="/home/builder/kernel-out"
CONFIG="$OUT_DIR/.config"

echo "=== CRITICAL KCONFIG CHECK ==="
echo "Config file: $CONFIG"
echo

if [[ ! -f "$CONFIG" ]]; then
    echo "ERROR: Kernel .config not found at $CONFIG"
    exit 1
fi

# Helper function
check_symbol() {
    local sym="$1"
    local desc="$2"

    if grep -q "^$sym=y" "$CONFIG"; then
        printf "  [PASS] %-20s (%s built-in)\n" "$sym" "$desc"
    elif grep -q "^$sym=m" "$CONFIG"; then
        printf "  [PASS] %-20s (%s as module)\n" "$sym" "$desc"
    else
        printf "  [FAIL] %-20s (%s missing!)\n" "$sym" "$desc"
        return 1
    fi
}

FAIL=0

echo "Checking critical kernel features..."
echo

check_symbol "CONFIG_BRIDGE_NETFILTER" "bridge netfilter" || FAIL=1
check_symbol "CONFIG_OVERLAY_FS"       "overlay filesystem" || FAIL=1
check_symbol "CONFIG_FUSE_FS"          "FUSE filesystem" || FAIL=1

echo
if [[ "$FAIL" -eq 0 ]]; then
    echo "=== ALL CRITICAL FEATURES PRESENT ==="
    exit 0
else
    echo "=== ONE OR MORE CRITICAL FEATURES ARE MISSING ==="
    echo "Review .config before deploying this kernel."
    exit 1
fi
