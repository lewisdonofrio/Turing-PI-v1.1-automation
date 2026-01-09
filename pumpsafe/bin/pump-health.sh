#!/bin/sh
# pump-health.sh
# Basic health checks for pumpsafe / pump mode.

set -eu

PYTHON_BIN="/usr/bin/python3"
RET=0

echo "==> pump-health: checking Python version..."
/opt/ansible-k3s-cluster/pumpsafe/bin/pump-python-version.sh || {
    echo "ERROR: Python version changed — run pump-restore.sh."
    RET=1
}

echo "==> pump-health: checking include_server.run lifetime..."
TMPDIR="$(mktemp -d /tmp/pump-health.XXXXXX)"
PORT="${TMPDIR}/socket"

cd /

"${PYTHON_BIN}" -m include_server.run include_server.py --port "${PORT}" /usr/bin/gcc &
PID=$!
sleep 2

if ps -p "${PID}" >/dev/null 2>&1; then
    echo "OK: include_server.run stays alive (PID ${PID})"
    kill "${PID}" 2>/dev/null || true
else
    echo "ERROR: include_server.run did not stay alive"
    RET=1
fi

exit "${RET}"
