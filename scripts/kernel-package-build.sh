#!/usr/bin/env bash
set -euo pipefail

PKGDIR="$1"

if [[ -z "$PKGDIR" ]]; then
    echo "Usage: $0 <package-dir>"
    exit 1
fi

cd "$PKGDIR"

echo "Building package in $PKGDIR"
makepkg -f --clean --cleanbuild

echo "Package build complete."
ls -1 *.pkg.tar.* || true
