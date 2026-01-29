#!/usr/bin/env bash
set -euo pipefail

# =====================================================================
#  /opt/ansible-k3s-cluster/scripts/staging-sync.sh
#
#  Purpose:
#    Synchronize the canonical script set from:
#       /opt/ansible-k3s-cluster/scripts
#    into the runtime execution directory:
#       /home/builder/scripts
#
#    This script:
#      - Creates a backup of the existing runtime scripts
#      - Clears the runtime directory
#      - Copies canonical scripts into place
#      - Applies executable permissions
#      - Shows a final listing for verification
#
#  Usage:
#      ./staging-sync.sh
#
#  Doctrine:
#    - /opt/... is canonical (Git-tracked, authoritative)
#    - /home/builder/scripts is runtime (PATH-first, builder-owned)
#    - This script does NOT run preflight or kernel-build
# =====================================================================

CANONICAL="/opt/ansible-k3s-cluster/scripts"
RUNTIME="/home/builder/scripts"
BACKUP="/home/builder/scripts.bak.$(date +%Y%m%d-%H%M%S)"

echo "==============================================================="
echo "  Staging runtime scripts from canonical source"
echo "==============================================================="
echo "Canonical: ${CANONICAL}"
echo "Runtime:   ${RUNTIME}"
echo "Backup:    ${BACKUP}"
echo ""

# ---------------------------------------------------------------------
# 1. Validate canonical directory
# ---------------------------------------------------------------------
if [[ ! -d "${CANONICAL}" ]]; then
    echo "ERROR: Canonical directory not found: ${CANONICAL}"
    exit 1
fi

# ---------------------------------------------------------------------
# 2. Backup existing runtime scripts
# ---------------------------------------------------------------------
echo "[1/4] Backing up existing runtime scripts to ${BACKUP}..."
mkdir -p "${BACKUP}"
mkdir -p "${RUNTIME}"

shopt -s nullglob
for f in "${RUNTIME}"/*; do
    mv "$f" "${BACKUP}/"
done
shopt -u nullglob

echo "OK: Runtime scripts backed up."

# ---------------------------------------------------------------------
# 3. Copy canonical scripts into runtime directory
# ---------------------------------------------------------------------
echo "[2/4] Copying canonical scripts into runtime directory..."
cp "${CANONICAL}"/* "${RUNTIME}/"
echo "OK: Canonical scripts copied."

# ---------------------------------------------------------------------
# 4. Apply executable permissions
# ---------------------------------------------------------------------
echo "[3/4] Applying executable permissions..."
chmod +x "${RUNTIME}"/*.sh
echo "OK: Permissions applied."

# ---------------------------------------------------------------------
# 5. Final verification
# ---------------------------------------------------------------------
echo "[4/4] Final runtime directory contents:"
ls -l "${RUNTIME}"

echo ""
echo "==============================================================="
echo "  Staging complete."
echo "  Next step: run kernel-build-preflight.sh manually."
echo "==============================================================="
