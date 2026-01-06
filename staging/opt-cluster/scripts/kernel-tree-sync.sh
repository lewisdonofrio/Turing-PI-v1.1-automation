#!/usr/bin/env bash
#
# =============================================================================
# File: /opt/cluster/scripts/kernel-tree-sync.sh
# =============================================================================
# Purpose:
#   Sync a clean kernel source tree into the builder tmpfs workspace.
#   Deterministic, idempotent, ASCII-only, nano-safe.
#
# Usage:
#   kernel-tree-sync.sh /path/to/source-tree
#
# Notes:
#   - Destination is always /tmp/kernel-build
#   - Source must be a directory containing a kernel tree
#   - Script refuses to run if source is missing or invalid
#   - Script refuses to run if tmpfs is not mounted
#   - Script uses rsync --delete for deterministic state
# =============================================================================

set -euo pipefail

SRC="${1:-}"
DST="/tmp/kernel-build"

# =============================================================================
# Validate environment
# =============================================================================

# Must be run by ansible or builder
USER_OK=0
if [ "$(id -un)" = "ansible" ]; then USER_OK=1; fi
if [ "$(id -un)" = "builder" ]; then USER_OK=1; fi
if [ "$USER_OK" -ne 1 ]; then
    echo "ERROR: This script must be run as ansible or builder."
    exit 1
fi

# rsync must exist
if ! command -v rsync >/dev/null 2>&1; then
    echo "ERROR: rsync not found in PATH."
    exit 1
fi

# =============================================================================
# Validate source
# =============================================================================

if [ -z "$SRC" ]; then
    echo "ERROR: No source directory provided."
    echo "Usage: $0 /path/to/kernel-source"
    exit 1
fi

if [ ! -d "$SRC" ]; then
    echo "ERROR: Source directory does not exist: $SRC"
    exit 1
fi

# Must contain Makefile
if [ ! -f "$SRC/Makefile" ]; then
    echo "ERROR: Source directory does not look like a kernel tree (missing Makefile)."
    exit 1
fi

# Must not be empty
if [ -z "$(ls -A "$SRC")" ]; then
    echo "ERROR: Source directory is empty: $SRC"
    exit 1
fi

# Must not contain nested kernel trees
if [ -d "$SRC/kernel" ]; then
    echo "ERROR: Source directory contains nested kernel/ directory."
    echo "This usually indicates an incorrect copy or sync."
    exit 1
fi

# =============================================================================
# Validate destination (tmpfs)
# =============================================================================

if ! mountpoint -q "$DST"; then
    echo "ERROR: Destination is not a mounted tmpfs: $DST"
    echo "Run builder-mode.sh first."
    exit 1
fi

if [ ! -w "$DST" ]; then
    echo "ERROR: Destination tmpfs is not writable: $DST"
    exit 1
fi

# =============================================================================
# Sync kernel tree
# =============================================================================

echo "Syncing kernel tree from:"
echo "  $SRC"
echo "to:"
echo "  $DST"
echo ""

rsync -a --delete "$SRC"/ "$DST"/

echo "Kernel tree synced to $DST"
echo "Done."
