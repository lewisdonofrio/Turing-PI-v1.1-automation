#!/bin/bash
set -euo pipefail

# ---------------------------------------------------------------------------
# pump-restore.sh (AUR version)
#
# Purpose:
#   Deterministically rebuild and reinstall the correct distcc-pump
#   include_server for Python 3.13 on the builder node.
#
# Notes:
#   - ASCII-only, nano-safe, idempotent.
#   - Builder-only.
# ---------------------------------------------------------------------------

AUR_DIR="/home/builder/src/distcc-pump-aur"
SITE_PKGS="/usr/lib/python3.13/site-packages"

echo "=== pump-restore: starting ==="

# ---------------------------------------------------------------------------
# 1. Ensure build dependencies
# ---------------------------------------------------------------------------
echo "Installing build dependencies..."
sudo pacman -Sy --noconfirm base-devel git python python-pip python-setuptools

# ---------------------------------------------------------------------------
# 2. Remove any broken include_server
# ---------------------------------------------------------------------------
echo "Removing old include_server..."
sudo rm -rf "${SITE_PKGS}/include_server" || true

# ---------------------------------------------------------------------------
# 3. Fetch AUR distcc-pump package
# ---------------------------------------------------------------------------
echo "Fetching AUR distcc-pump..."
rm -rf "${AUR_DIR}" || true
mkdir -p "${AUR_DIR}"
cd "${AUR_DIR}"

git clone https://aur.archlinux.org/distcc-pump.git .
# AUR packages have PKGBUILD, not pump/ directories

# ---------------------------------------------------------------------------
# 4. Build the AUR package
# ---------------------------------------------------------------------------
echo "Building distcc-pump AUR package..."
makepkg -si --noconfirm

# ---------------------------------------------------------------------------
# 5. Verify installation
# ---------------------------------------------------------------------------
echo "Verifying include_server installation..."
python3 - <<'EOF'
import include_server, sys
print("include_server loaded from:", include_server.__file__)
print("python:", sys.executable)
EOF

# ---------------------------------------------------------------------------
# 6. Ensure C extension layout
# ---------------------------------------------------------------------------
echo "Ensuring C extension layout..."
EXT=$(find "${SITE_PKGS}/include_server" -name "distcc_pump_c_extensions*.so" | head -n 1)
if [[ -z "${EXT}" ]]; then
    echo "ERROR: C extension missing after install."
    exit 1
fi

TARGET_DIR="${SITE_PKGS}/include_server/c_extensions/build/lib.linux-armv7l-cpython-313"
sudo mkdir -p "${TARGET_DIR}"
sudo ln -sf "${EXT}" "${TARGET_DIR}/distcc_pump_c_extensions.cpython-313-arm-linux-gnueabihf.so"

echo "C extension linked into expected layout."

# ---------------------------------------------------------------------------
# 7. Test include_server in foreground
# ---------------------------------------------------------------------------
echo "Testing include_server foreground startup..."
TMPDIR=$(mktemp -d /tmp/distcc-pump.test.XXXXXX)
PORT="${TMPDIR}/socket"

python3 -m include_server.run --port "${PORT}" /usr/bin/gcc &
PID=$!
sleep 1

if ps -p "${PID}" >/dev/null 2>&1; then
    echo "include_server started successfully (PID ${PID})"
    kill "${PID}" || true
else
    echo "ERROR: include_server failed to start."
    exit 1
fi

echo "=== pump-restore: completed successfully ==="
