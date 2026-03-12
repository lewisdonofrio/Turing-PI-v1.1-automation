#!/usr/bin/env bash
set -euo pipefail

STAGE="${1:-}"
PKGDIR="${2:-}"

if [[ -z "$STAGE" || -z "$PKGDIR" ]]; then
    echo "Usage: $0 <staged-tree> <package-dir>"
    exit 1
fi

if [[ ! -d "$STAGE/boot" ]]; then
    echo "ERROR: staged tree missing /boot"
    exit 1
fi

# Detect module root (canonical or legacy)
if [[ -d "$STAGE/usr/lib/modules" ]]; then
    MODROOT="$STAGE/lib/modules"
elif [[ -d "$STAGE/lib/modules" ]]; then
    MODROOT="$STAGE/lib/modules"
else
    echo "ERROR: staged tree missing modules directory"
    exit 1
fi

# Detect kernel version (directory name under modules/)
KVER=$(basename "$MODROOT"/*)
echo "Detected kernel version: $KVER"

# Normalize pkgver: strip everything after first hyphen
PKGVER="${KVER%%-*}"
PKGREL="1"

mkdir -p "$PKGDIR"/{pkg,src}

# Copy staged boot + modules into pkg/src
mkdir -p "$PKGDIR/src/boot"
mkdir -p "$PKGDIR/src/usr/lib/modules/$KVER"

cp -a "$STAGE/boot/." "$PKGDIR/src/boot/"
cp -a "$MODROOT/$KVER/" "$PKGDIR/src/usr/lib/modules/$KVER/"

# Generate PKGBUILD header (variables expand here)
cat > "$PKGDIR/PKGBUILD" <<EOF
pkgname=linux-rpi-custom
pkgver=${PKGVER}
pkgrel=${PKGREL}
arch=('armv7h')
pkgdesc="Custom Raspberry Pi kernel ${KVER}"
license=('GPL2')
source=()
sha256sums=()
prepare() { :; }

package() {
EOF
cat >> "$PKGDIR/PKGBUILD" <<'EOF'
    mkdir -p "$pkgdir/boot"
    mkdir -p "$pkgdir/usr/lib/modules/$KVER"

    cp -a "$STAGE/boot" "$pkgdir/boot"
    cp -a "$STAGE/lib/modules/$KVER" "$pkgdir/usr/lib/modules/"
}
EOF

echo "PKGBUILD generated at $PKGDIR/PKGBUILD"
echo "Package directory ready."
