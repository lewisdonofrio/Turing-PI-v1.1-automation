#!/bin/sh
# /opt/ansible-k3s-cluster/pumpsafe/shims/pump-doctor.sh
# Deeper diagnostics for pump-mode configuration and environment

set -eu

PYTHON_BIN="/usr/bin/python3"

echo "==> pump-doctor: checking binaries on PATH..."
for bin in distcc pump gcc "${PYTHON_BIN}"; do
    if command -v "${bin}" >/dev/null 2>&1; then
        echo "OK: found ${bin} at $(command -v "${bin}")"
    else
        echo "ERROR: ${bin} not found on PATH"
    fi
done

echo
echo "==> pump-doctor: distcc version..."
if command -v distcc >/dev/null 2>&1; then
    distcc --version || true
fi

echo
echo "==> pump-doctor: pump help..."
if command -v pump >/dev/null 2>&1; then
    pump --help | head -n 10 || true
fi

echo
echo "==> pump-doctor: Python include_server version..."
"${PYTHON_BIN}" - <<'EOF' 2>/dev/null || echo "ERROR: include_server import failed"
import include_server
print("include_server module:", include_server.__file__)
EOF

echo
echo "==> pump-doctor: running pump-health.sh..."
if command -v pump-health.sh >/dev/null 2>&1; then
    pump-health.sh || echo "pump-health.sh reported issues."
else
    echo "WARNING: pump-health.sh not found on PATH"
fi
