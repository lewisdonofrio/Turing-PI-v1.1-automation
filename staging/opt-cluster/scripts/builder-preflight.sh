#!/bin/sh
set -eu

# =============================================================================
# File: /opt/cluster/scripts/builder-preflight.sh
# =============================================================================
# Purpose:
#   Run preflight checks before any kernel build. This script verifies:
#     - tmpfs mount at /tmp/kernel-build exists and is mounted
#     - mount is backed by systemd unit tmp-kernel\x2dbuild.mount
#     - helper script /usr/local/bin/builder-tmpfs-ensure exists and is executable
#     - basic toolchain components exist (make, gcc, ld)
#
#   ASCII-only. Nano-safe. No tabs. No Unicode. No timestamps.
#   Safe to run at any time of day or night. Idempotent.
# =============================================================================

MOUNTPOINT="/tmp/kernel-build"
UNIT_NAME="tmp-kernel\\x2dbuild.mount"
UNIT_PATH="/etc/systemd/system/tmp-kernel\\x2dbuild.mount"
ENSURE_SCRIPT="/usr/local/bin/builder-tmpfs-ensure"

fail() {
    echo "BUILDER PREFLIGHT FAILED: $*" >&2
    exit 1
}

info() {
    echo "BUILDER PREFLIGHT: $*"
}

# -----------------------------------------------------------------------------
# Check: helper script exists and is executable
# -----------------------------------------------------------------------------
if [ ! -x "$ENSURE_SCRIPT" ]; then
    fail "Missing or non-executable helper script: $ENSURE_SCRIPT"
fi

# -----------------------------------------------------------------------------
# Check: systemd unit exists
# -----------------------------------------------------------------------------
if [ ! -f "$UNIT_PATH" ]; then
    fail "Missing systemd unit file: $UNIT_PATH"
fi

# -----------------------------------------------------------------------------
# Ensure tmpfs mount is present via helper script
# -----------------------------------------------------------------------------
info "Ensuring tmpfs mount via $ENSURE_SCRIPT"
"$ENSURE_SCRIPT"

# -----------------------------------------------------------------------------
# Verify: mountpoint exists and is a mount
# -----------------------------------------------------------------------------
if [ ! -d "$MOUNTPOINT" ]; then
    fail "Mountpoint directory missing after ensure: $MOUNTPOINT"
fi

if ! mountpoint -q "$MOUNTPOINT"; then
    fail "Mountpoint exists but is not a mount: $MOUNTPOINT"
fi

# -----------------------------------------------------------------------------
# Verify: filesystem type is tmpfs and size is at least 512M
# -----------------------------------------------------------------------------
# Note: rely on df output; no parsing of /proc directly for simplicity.
# -----------------------------------------------------------------------------
FS_TYPE=$(stat -f -c "%T" "$MOUNTPOINT" 2>/dev/null || echo "unknown")
if [ "$FS_TYPE" != "tmpfs" ]; then
    fail "Expected filesystem type tmpfs at $MOUNTPOINT, got: $FS_TYPE"
fi

# Check size using df (blocks * blocksize). Only verify minimum size.
SIZE_KB=$(df -k "$MOUNTPOINT" | awk 'NR==2 {print $2}')
# 512M = 524288K
if [ "$SIZE_KB" -lt 524288 ]; then
    fail "Expected tmpfs size >= 512M at $MOUNTPOINT, got ${SIZE_KB}K"
fi

# -----------------------------------------------------------------------------
# Check: basic toolchain presence
# -----------------------------------------------------------------------------
for bin in make gcc ld; do
    if ! command -v "$bin" >/dev/null 2>&1; then
        fail "Required tool not found in PATH: $bin"
    fi
done

info "All preflight checks passed."
# -----------------------------------------------------------------------------
# End of file
# -----------------------------------------------------------------------------
