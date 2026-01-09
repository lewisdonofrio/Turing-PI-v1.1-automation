# fullpath: /opt/ansible-k3s-cluster/pumpsafe/bin/pump-python-version.sh
# filename: pump-python-version.sh
# purpose: Track Python major.minor version for pumpsafe and trigger rebuild on change
# notes: ASCII-only, no tabs, no unicode, nano-safe, no timestamps

#!/bin/sh

set -eu

PYTHON_BIN="/usr/bin/python3"
STATE_FILE="/opt/ansible-k3s-cluster/pumpsafe/state/python-version.txt"

mkdir -p "$(dirname "${STATE_FILE}")"

CURRENT_VERSION="$(${PYTHON_BIN} - <<'EOF'
import sys
print(f"{sys.version_info.major}.{sys.version_info.minor}")
EOF
)"

if [ -f "${STATE_FILE}" ]; then
    PREVIOUS_VERSION="$(cat "${STATE_FILE}")"
else
    PREVIOUS_VERSION="none"
fi

echo "Current Python version: ${CURRENT_VERSION}"
echo "Previous Python version: ${PREVIOUS_VERSION}"

if [ "${CURRENT_VERSION}" != "${PREVIOUS_VERSION}" ]; then
    echo "Python version changed — pump mode must be rebuilt."
    echo "${CURRENT_VERSION}" > "${STATE_FILE}"
    exit 2
fi

exit 0
