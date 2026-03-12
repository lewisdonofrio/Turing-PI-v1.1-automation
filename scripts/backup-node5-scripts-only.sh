#!/usr/bin/env bash
set -euo pipefail

SRC_HOST="kubenode5.home.lab"
DEST_BASE="/home/builder/backups"

TS="$(date +%Y%m%d-%H%M%S)"
DEST_DIR="${DEST_BASE}/node5-scripts-${TS}"
STAGING="/tmp/node5-scripts-staging-${TS}"

echo "=== Creating staging directory: $STAGING ==="
mkdir -p "$STAGING"

echo "=== Pulling /home/builder/scripts from node5 ==="
rsync -aHAX --delete "${SRC_HOST}:/home/builder/scripts" "$STAGING/"

echo "=== Creating destination directory: $DEST_DIR ==="
mkdir -p "$DEST_DIR"

TARBALL="${DEST_DIR}/node5-scripts-${TS}.tar.gz"

echo "=== Creating tarball: $TARBALL ==="
tar -czf "$TARBALL" -C "$STAGING" .

echo "=== Cleaning staging ==="
rm -rf "$STAGING"

echo "Scripts backup stored at: $TARBALL"
