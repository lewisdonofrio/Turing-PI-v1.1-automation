#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$BASE_DIR/modules/normalize.sh"
source "$BASE_DIR/modules/tarops.sh"

tarball="$1"

echo "=== Checking for boot/kernel7.img ==="
if pre_collect_listing "$tarball" | grep -Fxq "boot/kernel7.img"; then
    echo "FOUND"
else
    echo "NOT FOUND"
fi
