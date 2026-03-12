#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$BASE_DIR/modules/normalize.sh"
source "$BASE_DIR/modules/tarops.sh"

tarball="$1"

echo "=== Extracting kernelrelease.txt ==="
if pre_extract_file "$tarball" "kernelrelease.txt" > out.txt; then
    echo "SUCCESS"
    cat out.txt
else
    echo "FAILED"
fi
