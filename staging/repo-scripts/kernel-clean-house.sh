#!/bin/sh
#
# kernel-clean-house.sh
#
# Purpose:
#   Perform a full, deterministic cleanup of the kernel build environment.
#   Removes corrupted or partial kernel source trees, stale module trees,
#   old deployment artifacts, and stale build logs.
#
# Usage:
#   sudo /home/builder/scripts/kernel-clean-house.sh
#
# Notes:
#   - ASCII-only, nano-safe, idempotent.
#   - Safe to run at any time.
#   - Does NOT remove user data outside kernel build paths.
#

echo "=== kernel-clean-house.sh ==="
echo "Starting full cleanup of kernel build environment..."
echo

# 1. Remove kernel source tree
if [ -d /home/builder/src/kernel ]; then
    echo "Removing kernel source tree: /home/builder/src/kernel"
    rm -rf /home/builder/src/kernel
else
    echo "Kernel source tree not present. Skipping."
fi
echo

# 2. Remove old module trees
echo "Removing old module trees under /lib/modules..."
for v in 6.12.62+ 6.18.1-1-rpi; do
    if [ -d /lib/modules/"$v" ]; then
        echo "Removing /lib/modules/$v"
        rm -rf /lib/modules/"$v"
    else
        echo "Module tree /lib/modules/$v not present. Skipping."
    fi
done
echo

# 3. Remove deployment staging directory
if [ -d /srv/kernel ]; then
    echo "Cleaning deployment staging directory: /srv/kernel"
    rm -rf /srv/kernel/*
else
    echo "Deployment staging directory /srv/kernel not present. Skipping."
fi
echo

# 4. Remove old build logs
if [ -d /home/builder/build-logs ]; then
    echo "Cleaning build logs: /home/builder/build-logs"
    rm -rf /home/builder/build-logs/*
else
    echo "Build logs directory not present. Skipping."
fi
echo

# 5. Recreate directories
echo "Recreating required directories..."
mkdir -p /home/builder/src
mkdir -p /home/builder/build-logs
mkdir -p /srv/kernel
echo

echo "Cleanup complete."
echo "Environment is now ready for a fresh kernel clone and build."
echo "==============================================="
