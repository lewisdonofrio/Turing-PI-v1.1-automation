#!/usr/bin/env bash
#
# =====================================================================
#  /home/builder/scripts/migrate-scripts-to-opt.sh
#
#  Purpose:
#    Copy all builder-owned scripts from /home/builder/scripts/ into
#    /opt/ansible-k3s-cluster/scripts/ for long-term storage and
#    version control. This script does not modify the originals.
#
#  Notes:
#    - ASCII-only, nano-safe, deterministic.
#    - No tabs, no Unicode, no timestamps.
#    - Must be run as builder on kubenode1.
#    - /opt/ansible-k3s-cluster/scripts/ must be root-owned.
#    - This script only copies; it does not delete or overwrite unless
#      explicitly confirmed by the user.
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

SRC="/home/builder/scripts"
DST="/opt/ansible-k3s-cluster/scripts"

if [ ! -d "$SRC" ]; then
    echo "ERROR: Source directory not found: $SRC"
    exit 1
fi

if [ ! -d "$DST" ]; then
    echo "ERROR: Destination directory not found: $DST"
    echo "Create it with:"
    echo "  sudo mkdir -p $DST"
    echo "  sudo chown root:root $DST"
    exit 1
fi

# ---------------------------------------------------------------------
#  Copy scripts with overwrite confirmation
# ---------------------------------------------------------------------

echo "Preparing to copy scripts from:"
echo "  $SRC"
echo "to:"
echo "  $DST"
echo

for f in "$SRC"/*.sh; do
    base=$(basename "$f")
    target="$DST/$base"

    if [ -f "$target" ]; then
        echo "WARNING: $target already exists"
        echo "Overwrite? (yes/no)"
        read answer
        if [ "$answer" != "yes" ]; then
            echo "Skipping $base"
            continue
        fi
    fi

    echo "Copying $base"
    sudo cp "$f" "$target"
done

echo "Migration complete."
