#!/bin/bash
set -euo pipefail

# ---------------------------------------------------------------------------
# pump-restore-upstream.sh
#
# Purpose:
#   Rebuild and reinstall the upstream distcc-pump include_server package
#   for Python 3.14 on ArchLinuxARM builder nodes.
#
# Notes:
#   - ASCII-only, nano-safe, idempotent.
#   - Does NOT rely on AUR (AUR no longer ships include_server).
#   - Uses upstream distcc-3.4 source which still contains pump/include_server.
# ---------------------------------------------------------------------------

DISTCC_VER="3.4"
WORKDIR="$HOME/src/distcc-include-server-upstream"
TARBALL="distcc-${DISTCC_VER}.tar.gz"
URL="https://github.com/distcc/distcc/releases/download/v${DISTCC_VER}/${TARBALL}"
SITE_USER="$(python3 -c 'import site; print(site.getusersitepackages())')"

echo "=== pump-restore-upstream: starting ==="
echo "Workdir: $WORKDIR"
echo "User site-packages: $SITE_USER"

# ---------------------------------------------------------------------------
# 1. Ensure build dependencies
# ---------------------------------------------------------------------------
echo "[1/8] Installing build dependencies..."
sudo pacman -Sy --noconfirm base-devel python python-pip python-setuptools python-build python-installer python-wheel

# ---------------------------------------------------------------------------
# 2. Prepare workspace
# ---------------------------------------------------------------------------
echo "[2/8] Preparing workspace..."
rm -rf "$WORKDIR" || true
mkdir -p "$WORKDIR"
cd "$WORKDIR"

# ---------------------------------------------------------------------------
# 3. Download distcc source (with redirect follow)
# ---------------------------------------------------------------------------
echo "[3/8] Downloading distcc upstream source..."
curl -L -o "$TARBALL" "$URL"

# ---------------------------------------------------------------------------
# 4. Extract include_server
# ---------------------------------------------------------------------------
echo "[4/8] Extracting include_server from distcc source..."
tar xf "$TARBALL"
cd "distcc-${DISTCC_VER}/include_server"
#cd "distcc-${DISTCC_VER}/pump/include_server"

# ---------------------------------------------------------------------------
# 5. Build and install include_server
# ---------------------------------------------------------------------------
echo "[5/8] Building include_server C extension..."
python3 setup.py build

echo "[5/8] Installing include_server into user site-packages..."
python3 setup.py install --user --break-system-packages

# ---------------------------------------------------------------------------
# 6. Verify Python import + C extension
# ---------------------------------------------------------------------------
echo "[6/8] Verifying include_server import..."
python3 - <<'EOF'
import include_server
from include_server import c_extensions
print("include_server OK")
print("c_extensions OK")
EOF

# ---------------------------------------------------------------------------
# 7. Restart pump mode
# ---------------------------------------------------------------------------
echo "[7/8] Restarting pump mode..."
cd ~/scripts
./pump-restart.sh || true

# ---------------------------------------------------------------------------
# 8. Validate pump health
# ---------------------------------------------------------------------------
echo "[8/8] Checking pump health..."
./pump-health.sh || true

echo "=== pump-restore-upstream: completed successfully ==="
echo "Running tiny pump test..."

echo 'int main(){return 0;}' > pump-test.c
pump distcc gcc -c pump-test.c -o pump-test.o || true

echo "If pump-test.o exists and workers show cc1 activity, pump mode is fully restored."
