#!/bin/sh
# /opt/ansible-k3s-cluster/pumpsafe/shims/pump-health.sh
# Simple health check for pump-mode

set -eu

PYTHON_BIN="/usr/bin/python3"
SITE_PKGS="/usr/lib/python3.13/site-packages"
SO_DIR="${SITE_PKGS}/include_server/c_extensions/build"
RET=0

echo "==> pump-health: checking include_server import..."
if ! "${PYTHON_BIN}" -c "import include_server" 2>/dev/null; then
    echo "ERROR: cannot import include_server"
    RET=1
else
    echo "OK: include_server import"
fi

echo "==> pump-health: checking C extension .so presence..."
if ! find "${SO_DIR}" -name 'distcc_pump_c_extensions*.so' | grep -q .; then
    echo "ERROR: no distcc_pump_c_extensions .so found under ${SO_DIR}"
    RET=1
else
    echo "OK: C extension present in ${SO_DIR}"
fi

echo "==> pump-health: checking include_server.run lifetime..."
TMPDIR="$(mktemp -d /tmp/pump-health.XXXXXX)"
PORT="${TMPDIR}/socket"

"${PYTHON_BIN}" -m include_server.run --port "${PORT}" -- /usr/bin/gcc &
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
