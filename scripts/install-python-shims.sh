#!/bin/bash
#
# install-python-shims.sh
#
# Purpose:
#   Install Python compatibility shims required for pump-mode include-server
#   when running on Python 3.13 or later.
#
# Location:
#   /opt/ansible-k3s-cluster/scripts/install-python-shims.sh
#
# Doctrine:
#   - Builder-only script.
#   - Idempotent: safe to run multiple times.
#   - No external dependencies.
#   - Ensures include-server can import "inotify".
#

set -e

PYVER="3.13"
SITEPKG="/usr/lib/python${PYVER}/site-packages"
PATCHDIR="/opt/ansible-k3s-cluster/lib/pump-mode/python-patches"

echo "Installing Python shims for pump-mode..."
echo "Python version: ${PYVER}"
echo "Site-packages:  ${SITEPKG}"
echo "Patch source:   ${PATCHDIR}"

# Ensure patch directory exists
if [ ! -d "${PATCHDIR}" ]; then
    echo "ERROR: Patch directory not found: ${PATCHDIR}"
    echo "Aborting."
    exit 1
fi

# Install inotify shim
if [ -f "${PATCHDIR}/inotify.py" ]; then
    echo "Copying inotify.py shim..."
    cp "${PATCHDIR}/inotify.py" "${SITEPKG}/inotify.py"
else
    echo "ERROR: inotify.py not found in ${PATCHDIR}"
    exit 1
fi

# Verify installation
if python3 - <<EOF
import inotify
print("Shim import OK")
EOF
then
    echo "Python shim installed successfully."
else
    echo "ERROR: Shim import failed."
    exit 1
fi

echo "Done."
