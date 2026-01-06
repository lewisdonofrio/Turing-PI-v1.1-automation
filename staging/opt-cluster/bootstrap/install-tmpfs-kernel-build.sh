#!/bin/sh
set -eu

# =============================================================================
# File: /opt/cluster/bootstrap/install-tmpfs-kernel-build.sh
# =============================================================================
# Purpose:
#   Install and activate the tmpfs mount for kernel builds from the /opt
#   repository into the live system:
#
#       Source unit:   /opt/cluster/systemd/tmp-kernel\x2dbuild.mount
#       Source script: /opt/cluster/scripts/builder-tmpfs-ensure
#
#       Target unit:   /etc/systemd/system/tmp-kernel\x2dbuild.mount
#       Target script: /usr/local/bin/builder-tmpfs-ensure
#
#   After this script completes successfully:
#       - /tmp/kernel-build exists with correct ownership and permissions
#       - tmp-kernel\x2dbuild.mount is installed and enabled
#       - tmpfs is mounted at /tmp/kernel-build
#
#   ASCII-only. Nano-safe. No tabs. No Unicode. No timestamps.
#   Safe to run at any time. Idempotent.
# =============================================================================

SRC_UNIT="/opt/cluster/systemd/tmp-kernel\\x2dbuild.mount"
DST_UNIT="/etc/systemd/system/tmp-kernel\\x2dbuild.mount"

SRC_SCRIPT="/opt/cluster/scripts/builder-tmpfs-ensure"
DST_SCRIPT="/usr/local/bin/builder-tmpfs-ensure"

UNIT_NAME="tmp-kernel\\x2dbuild.mount"

# -----------------------------------------------------------------------------
# Sanity checks for source files in /opt
# -----------------------------------------------------------------------------
if [ ! -f "$SRC_UNIT" ]; then
    echo "ERROR: Source unit file not found: $SRC_UNIT" >&2
    exit 1
fi

if [ ! -f "$SRC_SCRIPT" ]; then
    echo "ERROR: Source script not found: $SRC_SCRIPT" >&2
    exit 1
fi

# -----------------------------------------------------------------------------
# Install the systemd mount unit into /etc/systemd/system
# -----------------------------------------------------------------------------
install -m 0644 "$SRC_UNIT" "$DST_UNIT"

# -----------------------------------------------------------------------------
# Install the helper script into /usr/local/bin
# -----------------------------------------------------------------------------
install -m 0755 "$SRC_SCRIPT" "$DST_SCRIPT"

# -----------------------------------------------------------------------------
# Reload systemd, enable mount unit, and ensure tmpfs is active
# -----------------------------------------------------------------------------
systemctl daemon-reload
systemctl enable "$UNIT_NAME"

/usr/local/bin/builder-tmpfs-ensure

# -----------------------------------------------------------------------------
# End of file
# -----------------------------------------------------------------------------
