#!/usr/bin/env bash
#
# =============================================================================
# File: /opt/cluster/scripts/cluster-backup-validate.sh
# =============================================================================
# Purpose:
#   Validate backup integrity using POSIX 'sum' checksums.
#
#   Compares:
#     - /opt  <-> /mnt/storage/cluster-backup/opt
#     - /home <-> /mnt/storage/cluster-backup/home
#     - /root <-> /mnt/storage/cluster-backup/root
#
#   This script is ASCII-only, nano-safe, and deterministic.
# =============================================================================

set -euo pipefail

BACKUP_ROOT="/mnt/storage/cluster-backup"

declare -A PAIRS=(
    ["/opt"]="${BACKUP_ROOT}/opt"
    ["/home"]="${BACKUP_ROOT}/home"
    ["/root"]="${BACKUP_ROOT}/root"
)

log() {
    echo "CLUSTER-BACKUP-VALIDATE: $1"
}

fail() {
    echo "CLUSTER-BACKUP-VALIDATE ERROR: $1" >&2
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

# =============================================================================
# Compare checksums
# =============================================================================

MISMATCH=0

for SRC in "${!PAIRS[@]}"; do
    DST="${PAIRS[$SRC]}"

    log "Validating:"
    log "  SRC: ${SRC}"
    log "  DST: ${DST}"

    if [ ! -d "$DST" ]; then
        log "  Missing backup directory: ${DST}"
        MISMATCH=1
        continue
    fi

    TMP_SRC=$(mktemp)
    TMP_DST=$(mktemp)

    sudo find "$SRC" -type f -print0 | sudo xargs -0 sum | sort > "$TMP_SRC"
    sudo find "$DST" -type f -print0 | sudo xargs -0 sum | sort > "$TMP_DST"

    if ! diff -u "$TMP_SRC" "$TMP_DST" > /dev/null; then
        log "  CHECKSUM MISMATCH for ${SRC}"
        diff -u "$TMP_SRC" "$TMP_DST" || true
        MISMATCH=1
    else
        log "  OK"
    fi

    rm -f "$TMP_SRC" "$TMP_DST"
done

if [ "$MISMATCH" -eq 0 ]; then
    log "All backups validated successfully."
    exit 0
else
    fail "Backup validation failed."
fi
