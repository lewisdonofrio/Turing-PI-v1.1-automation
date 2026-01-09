#!/bin/sh
# /opt/ansible-k3s-cluster/pumpsafe/bin/pump-doctor.sh
# Quick diagnostics for pump mode.

set -eu

PYTHON_BIN="/usr/bin/python3"

echo "==> pump-doctor: Python version"
 /opt/ansible-k3s-cluster/pumpsafe/bin/pump-python-version.sh || {
    echo "WARN: Python version changed — run pump-restore.sh."
}

echo "==> pump-doctor: Python and include_server import"
"${PYTHON_BIN}" - <<'EOF'
import sys
print("Python:", sys.version)
try:
    import include_server
    print("include_server imported from:", include_server.__file__)
except Exception as e:
    print("ERROR importing include_server:", e)
EOF

echo "==> pump-doctor: include_server.run test"
TMPDIR="$(mktemp -d /tmp/pump-doctor.XXXXXX)"
PORT="${TMPDIR}/socket"

cd /

"${PYTHON_BIN}" -m include_server.run include_server.py --port "${PORT}" /usr/bin/gcc &
PID=$!
sleep 2

if ps -p "${PID}" >/dev/null 2>&1; then
    echo "OK: include_server.run stays alive (PID ${PID})"
    kill "${PID}" 2>/dev/null || true
else
    echo "ERROR: include_server.run failed to stay alive"
fi
