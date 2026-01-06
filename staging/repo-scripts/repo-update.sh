#!/bin/bash
# /opt/ansible-k3s-cluster/scripts/repo-update.sh
# Update local pacman repo with latest linux-rpi-6.18-k3s package.
# Doctrine:
#   - Repo lives at /home/builder/repo/k3s-kernel
#   - Packages live at /home/builder/pkgout
#   - Repo database is rebuilt every run
#   - Only packages matching linux-rpi-6.18-k3s-* are included

set -euo pipefail

REPO="/home/builder/repo/k3s-kernel"
PKGOUT="/home/builder/pkgout"
PKGNAME="linux-rpi-6.18-k3s"

mkdir -p "$REPO"

# ------------------------------------------------------------
# Find latest package
# ------------------------------------------------------------
LATEST_PKG="$(ls -1t "$PKGOUT"/${PKGNAME}-*.pkg.tar.zst 2>/dev/null | head -n 1)"

if [[ -z "${LATEST_PKG}" ]]; then
    echo "ERROR: No ${PKGNAME} package found in $PKGOUT"
    exit 1
fi

echo "Using package: $LATEST_PKG"

# ------------------------------------------------------------
# Copy package into repo
# ------------------------------------------------------------
cp "$LATEST_PKG" "$REPO/"

# ------------------------------------------------------------
# Rebuild repo database
# ------------------------------------------------------------
repo-add "$REPO/k3s-kernel.db.tar.gz" "$REPO"/${PKGNAME}-*.pkg.tar.zst

echo "Local repo updated at $REPO"
echo "Repo now contains:"
ls -1 "$REPO" | sed 's/^/  /'
