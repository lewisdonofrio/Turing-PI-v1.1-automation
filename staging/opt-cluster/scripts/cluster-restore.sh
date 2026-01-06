#!/usr/bin/env bash
#
# =============================================================================
# File: /opt/cluster/scripts/cluster-restore.sh
# =============================================================================
# Purpose:
#   Restore system state from backup using deterministic rsync.
#
#   Restores:
#     - /opt
#     - /home
#     - /root
#
#   Source:
#     - /mnt/storage/cluster-backup
#
#   This script is ASCII-only, nano-safe, and idempotent.
# =============================================================================

set -euo pipefail

BACKUP_ROOT="/mnt/storage/cluster-backup"

SRC_OPT="${BACKUP_ROOT}/opt"
SRC_HOME="${BACKUP_ROOT}/home"
SRC_ROOT="${BACKUP_ROOT}/root"

DST_OPT="/opt"
DST_HOME="/home"
DST_ROOT="/root"

log() {
    echo "CLUSTER-RESTORE: $1"
}

fail() {
    echo "CLUSTER-RESTORE ERROR: $1" >&2
    exit 1
}

# =============================================================================
# Validate caller
# =============================================================================

CURRENT_USER="$(id -un)"

if [ "$CURRENT_USER" != "ansible" ]; then
    fail "This script must be run as the ansible user (current: $CURRENT_USER)."
fi

# =============================================================================
# Validate backup root
# =============================================================================

if [ ! -d "$BACKUP_ROOT" ]; then
    fail "Backup root does not exist: ${BACKUP_ROOT}"
fi

log "Using backup root: ${BACKUP_ROOT}"

# =============================================================================
# Validate backup sources
# =============================================================================

[ -d "$SRC_OPT" ]  || fail "Backup missing: ${SRC_OPT}"
[ -d "$SRC_HOME" ] || fail "Backup missing: ${SRC_HOME}"
[ -d "$SRC_ROOT" ] || fail "Backup missing: ${SRC_ROOT}"

# =============================================================================
# Confirm restore
# =============================================================================

echo "WARNING: This will overwrite /opt, /home, and /root with backup data."
echo "This operation is destructive and cannot be undone."
echo
read -p "Type RESTORE to continue: " CONFIRM

if [ "$CONFIRM" != "RESTORE" ]; then
    fail "Restore aborted by user."
fi

log "Restore confirmed."

# =============================================================================
# Perform restore (sudo rsync)
# =============================================================================

do_restore() {
    SRC="$1"
    DST="$2"

    log "Restoring:"
    log "  SRC: ${SRC}"
    log "  DST: ${DST}"

    sudo rsync -a --delete "${SRC}/" "${DST}/"
}

do_restore "$SRC_OPT"  "$DST_OPT"
do_restore "$SRC_HOME" "$DST_HOME"
do_restore "$SRC_ROOT" "$DST_ROOT"

log "Restore complete."

exit 0
