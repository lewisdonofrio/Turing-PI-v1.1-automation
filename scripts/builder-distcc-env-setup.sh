#!/bin/bash
set -euo pipefail

# ---------------------------------------------------------------------
#  /home/builder/scripts/builder-distcc-env-setup.sh
#
#  Purpose:
#    - Prepare distcc + pump environment WITHOUT PATH masquerade.
#    - Keep /etc/distcc/hosts canonical (no DISTCC_HOSTS override).
#    - Prepare a dedicated pump directory.
#
#  Notes:
#    - We intentionally DO NOT prepend /usr/lib/distcc/bin to PATH.
#      Kconfig must see the real gcc, not the distcc shim.
#    - Pump/distcc will still be used for compilation via CC="distcc gcc".
# ---------------------------------------------------------------------

DISTCC_BIN_DIR="/usr/lib/distcc/bin"

# ---------------------------------------------------------------------
#  IMPORTANT DOCTRINE CHANGE:
#  Disable PATH masquerade. Do NOT prepend distcc shims.
#  This keeps Kconfig stable while still allowing pump-mode distcc
#  through CC="distcc gcc" during actual compilation.
# ---------------------------------------------------------------------

# (PATH override removed)

# ---------------------------------------------------------------------
#  Pump directory for include_server socket
# ---------------------------------------------------------------------
export DISTCC_PUMP_DIR="/tmp/distcc-pump-${USER}"
mkdir -p "${DISTCC_PUMP_DIR}"

# ---------------------------------------------------------------------
#  Visibility
# ---------------------------------------------------------------------
echo "PATH=${PATH}"
echo "DISTCC_PUMP_DIR=${DISTCC_PUMP_DIR}"

if [[ -f /etc/distcc/hosts ]]; then
    echo "Using /etc/distcc/hosts:"
    sed 's/^/  /' /etc/distcc/hosts
fi
