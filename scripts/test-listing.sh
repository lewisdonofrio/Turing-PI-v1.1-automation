#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$BASE_DIR/modules/normalize.sh"
source "$BASE_DIR/modules/tarops.sh"

tarball="$1"

echo "=== RAW LISTING ==="
tar -t -f "$tarball" | head

echo
echo "=== NORMALIZED LISTING ==="
pre_collect_listing "$tarball" | head
