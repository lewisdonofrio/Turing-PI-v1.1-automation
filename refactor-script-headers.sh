#!/bin/bash
set -euo pipefail

# =====================================================================
#  refactor-script-headers.sh
#
#  Purpose:
#    Rewrite old script header paths from:
#      /home/builder/scripts/<script>.sh
#    to:
#      /opt/ansible-k3s-cluster/scripts/<script>.sh
#
#    Only affects comment/header lines.
#    Does NOT touch runtime paths or Ansible playbooks.
# =====================================================================

ROOT="/opt/ansible-k3s-cluster/scripts"

echo "Refactoring script headers under ${ROOT}..."

# ---------------------------------------------------------------------
# Replace header lines beginning with '#  /home/builder/scripts/...'
# ---------------------------------------------------------------------
grep -Rl "^#.*home/builder/scripts" "${ROOT}" | while read -r FILE; do
    echo "Updating header in: ${FILE}"
    sed -i \
        -e "s|#  /home/builder/scripts|#  /opt/ansible-k3s-cluster/scripts|g" \
        -e "s|# File: /home/builder/scripts|# File: /opt/ansible-k3s-cluster/scripts|g" \
        "${FILE}"
done

echo "=============================================================="
echo " Header refactor complete."
echo " Only documentation headers were updated."
echo "=============================================================="
