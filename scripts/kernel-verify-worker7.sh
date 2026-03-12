#!/usr/bin/env bash
#
# =====================================================================
#  /home/builder/scripts/kernel-verify-worker7.sh
#
#  Purpose:
#    Perform deeper verification of worker7's kernel state after upgrade:
#    - Confirm expected kernelrelease
#    - Inspect /boot contents
#    - Compare module counts vs last backup (if found)
#
#  Notes:
#    - ASCII-only, nano-safe, deterministic.
#    - Must be run as builder on kubenode1.
#    This script assumes your backups look like 
#      /var/backups/kernel-YYYYMMDD-HHMMSS/... as in the backup script.
# =====================================================================

set -euo pipefail

TARGET="kubenode7.home.lab"
BACKUP_GLOB="/var/backups/kernel-*"

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

if ! ssh "$TARGET" "echo ok" >/dev/null 2>&1; then
    echo "ERROR: Unable to reach $TARGET via SSH"
    exit 1
fi

echo "Running kernel verification on $TARGET"
echo

# ---------------------------------------------------------------------
#  Current kernelrelease
# ---------------------------------------------------------------------

KREL=$(ssh "$TARGET" "uname -r")
echo "Current kernelrelease on $TARGET: $KREL"
echo

# ---------------------------------------------------------------------
#  /boot structure check
# ---------------------------------------------------------------------

echo "Inspecting /boot on $TARGET..."

ssh "$TARGET" '
    echo "Listing /boot:"
    ls -1 /boot || echo "WARNING: Unable to list /boot"

    echo
    echo "Checking for common kernel files:"
    for f in kernel7.img zImage Image cmdline.txt config.txt; do
        if [ -f "/boot/$f" ]; then
            echo "  FOUND: /boot/$f"
        else
            echo "  MISSING: /boot/$f"
        fi
    done

    if [ -d /boot/overlays ]; then
        echo
        echo "Overlays directory exists: /boot/overlays"
        ls -1 /boot/overlays | head -20 || true
    else
        echo "WARNING: /boot/overlays directory missing"
    fi
'
echo

# ---------------------------------------------------------------------
#  Module count on target
# ---------------------------------------------------------------------

echo "Counting modules on $TARGET..."

ssh "$TARGET" "
    MODDIR=\"/usr/lib/modules/$KREL\"
    if [ -d \"\$MODDIR\" ]; then
        echo \"Modules directory: \$MODDIR\"
        find \"\$MODDIR\" -type f -name \"*.ko\" | wc -l
    else
        echo \"WARNING: Modules directory missing: \$MODDIR\"
    fi
"
echo

# ---------------------------------------------------------------------
#  Compare to last backup (if any)
# ---------------------------------------------------------------------

echo "Comparing module count to last kernel backup (if available)..."
LAST_BACKUP=$(ls -1d $BACKUP_GLOB 2>/dev/null | sort | tail -n 1 || true)

if [ -z "$LAST_BACKUP" ]; then
    echo "No previous kernel backups found under /var/backups."
else
    echo "Last backup directory: $LAST_BACKUP"
    if [ -d "$LAST_BACKUP/modules" ]; then
        echo "Module count in last backup:"
        find "$LAST_BACKUP/modules" -type f -name "*.ko" | wc -l
    else
        echo "WARNING: No modules directory in last backup"
    fi
fi

echo
echo "Kernel verification complete for $TARGET."
