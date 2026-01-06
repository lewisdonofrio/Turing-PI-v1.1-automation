#!/usr/bin/env bash
#
# =====================================================================
#  /home/builder/scripts/kernel-clone-to-worker7.sh
#
#  Purpose:
#    Synchronize kernel-related files from the builder node (slot 0)
#    to worker7 for safe kernel testing. This allows worker7 to act as
#    a testbed for new kernels without risking the primary builder.
#
#  Notes:
#    - ASCII-only, nano-safe, deterministic.
#    - No tabs, no Unicode, no timestamps.
#    - Must be run as builder on kubenode1.
#    - Only synchronizes kernel artifacts, modules, and /boot files.
#    - Does not modify system identity or cluster roles.
# =====================================================================

set -euo pipefail

# ---------------------------------------------------------------------
#  Environment validation
# ---------------------------------------------------------------------

if [ "$(whoami)" != "builder" ]; then
    echo "ERROR: Must run as builder user"
    exit 1
fi

if [ "$(hostname)" != "kubenode1" ]; then
    echo "ERROR: Must run on kubenode1"
    exit 1
fi

TARGET="kubenode7.home.lab"

echo "Preparing to clone kernel artifacts to $TARGET"
echo

# ---------------------------------------------------------------------
#  Verify target is reachable
# ---------------------------------------------------------------------

if ! ssh "$TARGET" "echo ok" >/dev/null 2>&1; then
    echo "ERROR: Unable to reach $TARGET via SSH"
    exit 1
fi

# ---------------------------------------------------------------------
#  Paths
# ---------------------------------------------------------------------

SRC_BOOT="/boot"
SRC_MOD="/usr/lib/modules"
SRC_ART="/home/builder/artifacts/kernel"
SRC_PKG="/home/builder/pkgout"

DST_BOOT="/boot"
DST_MOD="/usr/lib/modules"
DST_PKG="/home/builder/pkgout"

# ---------------------------------------------------------------------
#  Confirm action
# ---------------------------------------------------------------------

echo "This will synchronize:"
echo "  - /boot (kernel files only)"
echo "  - /usr/lib/modules/<version>"
echo "  - packaged kernel artifacts"
echo
echo "Firmware files (start.elf, fixup.dat, bootcode.bin) will NOT be touched."
echo
echo "Proceed with cloning to $TARGET? (yes/no)"
read answer

if [ "$answer" != "yes" ]; then
    echo "Aborting."
    exit 0
fi

# ---------------------------------------------------------------------
#  Sync /boot (kernel files only)
# ---------------------------------------------------------------------

echo "Syncing kernel files in /boot..."

ssh "$TARGET" "sudo mkdir -p $DST_BOOT"

rsync -av \
    --include="kernel*.img" \
    --include="*.dtb" \
    --include="overlays/" \
    --include="overlays/*.dtbo" \
    --exclude="*" \
    "$SRC_BOOT/" "$TARGET:$DST_BOOT/"

# ---------------------------------------------------------------------
#  Sync modules
# ---------------------------------------------------------------------

echo "Syncing /usr/lib/modules..."

ssh "$TARGET" "sudo mkdir -p $DST_MOD"

rsync -av "$SRC_MOD/" "$TARGET:$DST_MOD/"

# ---------------------------------------------------------------------
#  Sync packaged kernel artifacts
# ---------------------------------------------------------------------

echo "Syncing packaged kernel artifacts..."

ssh "$TARGET" "mkdir -p $DST_PKG"

rsync -av "$SRC_PKG/" "$TARGET:$DST_PKG/"

# ---------------------------------------------------------------------
#  Summary
# ---------------------------------------------------------------------

echo "Clone to worker7 complete."
echo "Worker7 is now ready for kernel testing."
