#!/bin/bash
# /home/builder/scripts/fix-distcc-pump-env.sh
# Ensures pump uses the correct hostfile by exporting DISTCC_DIR globally.

set -e

echo "[+] Creating /etc/profile.d/distcc-dir.sh"
sudo tee /etc/profile.d/distcc-dir.sh >/dev/null <<'EOF'
# Ensure distcc and pump use the correct hostfile
export DISTCC_DIR="/home/builder/.distcc"
EOF

echo "[+] Setting permissions"
sudo chmod 644 /etc/profile.d/distcc-dir.sh

echo "[+] Reloading environment"
source /etc/profile

echo "[+] Verifying DISTCC_DIR"
env | grep DISTCC_DIR || echo "[-] DISTCC_DIR not found in environment"

echo "[+] Restarting pump"
pump --shutdown || true
pump --startup

echo "[+] Checking include-server"
ps aux | grep include-server
