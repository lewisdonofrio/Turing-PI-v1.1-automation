#!/usr/bin/env bash
#
# =============================================================================
# File: /opt/cluster/scripts/cluster-backup.sh
# =============================================================================
# Purpose:
#   Deterministic backup of critical system state to local storage.
#
#   Backs up:
#     - /opt
#     - /home
#     - /root
#
#   Destination:
#     - /mnt/storage/cluster-backup
#
#   This script is ASCII-only, nano-safe, and idempotent.
# =============================================================================

set -euo pipefail

BACKUP_ROOT="/mnt/storage/cluster-backup"

SRC_OPT="/opt"
SRC_HOME="/home"
SRC_ROOT="/root"

log() {
    echo "CLUSTER-BACKUP: $1"
}

fail() {
    echo "CLUSTER-BACKUP ERROR: $1" >&2
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

if [ ! -w "$BACKUP_ROOT" ]; then
    fail "Backup root is not writable: ${BACKUP_ROOT}"
fi

log "Using backup root: ${BACKUP_ROOT}"

mkdir -p \
    "${BACKUP_ROOT}/opt" \
    "${BACKUP_ROOT}/home" \
    "${BACKUP_ROOT}/root"

# =============================================================================
# Validate sources
# =============================================================================

[ -d "$SRC_OPT" ]  || fail "Source directory missing: ${SRC_OPT}"
[ -d "$SRC_HOME" ] || fail "Source directory missing: ${SRC_HOME}"
[ -d "$SRC_ROOT" ] || fail "Source directory missing: ${SRC_ROOT}"

# =============================================================================
# Run rsync backups (with sudo for full access)
# =============================================================================

do_rsync() {
    SRC="$1"
    DST="$2"

    log "Backing up:"
    log "  SRC: ${SRC}"
    log "  DST: ${DST}"

    sudo rsync -a --delete "${SRC}/" "${DST}/"
}

do_rsync "$SRC_OPT"  "${BACKUP_ROOT}/opt"
do_rsync "$SRC_HOME" "${BACKUP_ROOT}/home"
do_rsync "$SRC_ROOT" "${BACKUP_ROOT}/root"

log "Backup complete."

exit 0
