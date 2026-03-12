#!/usr/bin/env bash
set -euo pipefail

SRC_HOST="kubenode5.home.lab"
DEST_BASE="/home/builder/backups"

TS="$(date +%Y%m%d-%H%M%S)"
DEST_DIR="${DEST_BASE}/node5-${TS}"
STAGING="/tmp/node5-backup-staging-${TS}"

echo "=== Creating staging directory on node1: $STAGING ==="
mkdir -p "$STAGING"

declare -a PATHS=(
  "/home/builder/scripts"
  "/boot"
  "/lib/modules"
  "/usr/lib/modules"
)

echo "=== Pulling directories from node5 into staging ==="
for p in "${PATHS[@]}"; do
  echo "Pulling $p"
  rsync -aHAX --delete "${SRC_HOST}:${p}" "${STAGING}/" || echo "Skipping missing path: $p"
done

echo "=== Freezing staging and creating destination directory ==="
mkdir -p "$DEST_DIR"

TARBALL="${DEST_DIR}/node5-backup-${TS}.tar.gz"

echo "=== Creating tarball: $TARBALL ==="
tar -czf "$TARBALL" -C "$STAGING" .

echo "=== Cleaning up staging ==="
rm -rf "$STAGING"

echo "=== Backup complete ==="
echo "Stored at: $TARBALL"
