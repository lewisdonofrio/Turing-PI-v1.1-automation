#!/bin/bash
# =============================================================================
# File: /opt/ansible-k3s-cluster/tools/fix-builder-distcc.sh
# Purpose:
#   Repair the builder-side distcc environment so that distributed
#   compilation works correctly with ArchLinuxARM workers.
#
#   This script:
#     - Ensures gcc is installed
#     - Ensures real compilers exist in /usr/bin
#     - Repairs /usr/lib/distcc/bin wrapper directory
#     - Ensures PATH ordering is correct
#     - Verifies distcc can find the real compiler
#     - Performs a test compile
#
# Notes:
#   - ASCII-only, nano-safe, no Unicode, no tabs
#   - Idempotent: safe to run multiple times
#   - This script modifies only the builder, not the workers
# =============================================================================

set -e

echo "====================================================================="
echo " FIXING BUILDER DISTCC ENVIRONMENT"
echo "====================================================================="

echo ">>> Ensuring gcc is installed"
sudo pacman -Sy --noconfirm gcc

echo ">>> Ensuring real compilers exist"
for bin in gcc cc g++; do
    if [ ! -x "/usr/bin/$bin" ]; then
        echo "ERROR: /usr/bin/$bin missing"
        exit 1
    fi
done

echo ">>> Repairing wrapper directory"
sudo mkdir -p /usr/lib/distcc/bin
sudo rm -f /usr/lib/distcc/bin/*

sudo ln -s /usr/bin/distcc /usr/lib/distcc/bin/gcc
sudo ln -s /usr/bin/distcc /usr/lib/distcc/bin/cc
sudo ln -s /usr/bin/distcc /usr/lib/distcc/bin/g++

echo ">>> Ensuring PATH ordering"
export PATH="/usr/lib/distcc/bin:/usr/bin:/usr/local/bin:/usr/local/sbin:/usr/bin/site_perl:/usr/bin/vendor_perl:/usr/bin/core_perl"

echo ">>> Verifying wrapper chain"
distcc gcc --version || {
    echo "ERROR: distcc cannot find the real compiler"
    exit 1
}

echo ">>> Creating test file"
echo 'int main(){return 0;}' > test.c

echo ">>> Running distributed test compile"
distcc gcc -c test.c -o test.o || {
    echo "ERROR: distributed compile failed"
    exit 1
}

echo ">>> Test compile complete"

echo "====================================================================="
echo " BUILDER FIX COMPLETE — DISTCC SHOULD NOW WORK"
echo "====================================================================="
