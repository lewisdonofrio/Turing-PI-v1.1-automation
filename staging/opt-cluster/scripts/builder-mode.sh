#!/usr/bin/env bash
#
# =============================================================================
# File: /opt/cluster/scripts/builder-mode.sh
# =============================================================================
# Purpose:
#   Enter deterministic "builder mode" on the builder node.
#   - Validate /opt/cluster repository
#   - Run builder preflight checks
#   - Ensure tmpfs mount via builder-tmpfs-ensure
#
# Requirements:
#   - Must be run as ansible user
#   - ansible must have passwordless sudo
#   - /opt/cluster must exist and be readable
#   - /usr/local/bin/builder-tmpfs-ensure must exist and be executable
#
# Notes:
#   - This script is ASCII-only, nano-safe, and idempotent.
#   - All privileged operations are performed via sudo to avoid polkit prompts.
# =============================================================================

set -euo pipefail

REPO_DIR="/opt/cluster"
TMPFS_MOUNT="/tmp/kernel-build"
BUILDER_TMPFS_ENSURE="/usr/local/bin/builder-tmpfs-ensure"

# =============================================================================
# Helpers
# =============================================================================

log() {
    # Simple prefixed logger
    # Usage: log "MESSAGE"
    echo "$1"
}

fail() {
    echo "ERROR: $1" >&2
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
# Validate /opt/cluster repository
# =============================================================================

# Validate required files exist
REQUIRED_FILES="
${REPO_DIR}/scripts/builder-preflight.sh
${REPO_DIR}/scripts/builder-tmpfs-ensure
${REPO_DIR}/scripts/repo-validate.sh
"

for f in $REQUIRED_FILES; do
    if [ ! -f "$f" ]; then
        fail "Required file missing: $f"
    fi
done

log "REPO VALIDATE: All required files present."

# =============================================================================
# Builder preflight: ensure tmpfs via builder-tmpfs-ensure
# =============================================================================

log "BUILDER MODE: Running builder preflight checks"

if [ ! -x "$BUILDER_TMPFS_ENSURE" ]; then
    fail "builder-tmpfs-ensure not found or not executable: ${BUILDER_TMPFS_ENSURE}"
fi

log "BUILDER PREFLIGHT: Ensuring tmpfs mount via ${BUILDER_TMPFS_ENSURE}"

# Run via sudo to avoid polkit prompts from systemctl inside the helper
sudo "$BUILDER_TMPFS_ENSURE"

# =============================================================================
# Validate tmpfs mount
# =============================================================================

if ! mountpoint -q "$TMPFS_MOUNT"; then
    fail "Tmpfs mount is not active at ${TMPFS_MOUNT} after builder-tmpfs-ensure."
fi

if [ ! -w "$TMPFS_MOUNT" ]; then
    fail "Tmpfs mount at ${TMPFS_MOUNT} is not writable."
fi

log "BUILDER MODE: Tmpfs mount confirmed at ${TMPFS_MOUNT}"

# =============================================================================
# Final summary
# =============================================================================

log "BUILDER MODE: Environment ready for kernel-tree-sync and builds."
log "BUILDER MODE: Next steps (typical):"
log "  /opt/cluster/scripts/kernel-tree-sync.sh /home/builder/linux-rpi-k3s"
log "  cd ${TMPFS_MOUNT}"
log "  make -j14"

exit 0
