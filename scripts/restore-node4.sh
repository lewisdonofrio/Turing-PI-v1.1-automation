#!/usr/bin/env bash
set -euo pipefail

# --- CONFIGURATION ---------------------------------------------------------

SRC_BACKUP_DIR="$1"   # e.g. /home/builder/backups/node5-20260118-035853
SRC_HOST="kubenode1.home.lab"
DEST_HOST="kubenode4.home.lab"

STAGING_BASE="/tmp/node4-restore-staging"
TS="$(date +%Y%m%d-%H%M%S)"
STAGING="${STAGING_BASE}-${TS}"

# --- VALIDATION ------------------------------------------------------------

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <backup-directory>"
  echo "Example:"
  echo "  $0 /home/builder/backups/node5-20260118-035853"
  exit 1
fi

if [[ ! -d "$SRC_BACKUP_DIR" ]]; then
  echo "ERROR: Backup directory not found: $SRC_BACKUP_DIR"
  exit 1
fi

TARBALL="$(find "$SRC_BACKUP_DIR" -maxdepth 1 -name '*.tar.gz' | head -n 1)"

if [[ -z "$TARBALL" ]]; then
  echo "ERROR: No tarball found in backup directory: $SRC_BACKUP_DIR"
  exit 1
fi

echo "=== Using backup tarball: $TARBALL ==="

# --- STAGING ---------------------------------------------------------------

echo "=== Creating staging directory: $STAGING ==="
mkdir -p "$STAGING"

echo "=== Extracting backup into staging ==="
tar -xzf "$TARBALL" -C "$STAGING"

echo "=== Staging contents ready ==="
ls -l "$STAGING"

# --- RESTORE TO NODE4 ------------------------------------------------------

echo "=== Restoring to node4: $DEST_HOST ==="

declare -a PATHS=(
  "home/builder/scripts"
  "boot"
  "lib/modules"
  "usr/lib/modules"
)

for p in "${PATHS[@]}"; do
  if [[ -e "$STAGING/$p" ]]; then
    echo "Restoring $p to node4"
    rsync -aHAX --delete "$STAGING/$p" "${DEST_HOST}:/$p"
  else
    echo "Skipping missing path in backup: $p"
  fi
done

echo "=== Restore complete ==="
echo "Node4 now has the restored filesystem state from: $SRC_BACKUP_DIR"
echo "You may now run your validator or deploy scripts on node4."

