#!/bin/sh
# /opt/cluster/scripts/kernel-clean-house.sh
# Purpose: Remove all artifacts from the invalid 6.12 kernel build to ensure a clean environment for 6.18.1.
# Usage: sudo sh /opt/cluster/scripts/kernel-clean-house.sh
# Notes: ASCII-only, nano-safe, deterministic, idempotent. Safe to run multiple times.

set -eu

echo "== Cleaning invalid 6.12 kernel artifacts =="

# 1. Remove invalid source tree
if [ -d /home/builder/src/kernel ] ; then
    echo "Removing /home/builder/src/kernel"
    rm -rf /home/builder/src/kernel
else
    echo "OK: /home/builder/src/kernel already removed"
fi

# 2. Remove invalid modules
if [ -d /lib/modules/6.12.62+ ] ; then
    echo "Removing /lib/modules/6.12.62+"
    rm -rf /lib/modules/6.12.62+
else
    echo "OK: /lib/modules/6.12.62+ already removed"
fi

# 3. Remove invalid staged modules
if [ -d /srv/kernel/modules/6.12.62+ ] ; then
    echo "Removing /srv/kernel/modules/6.12.62+"
    rm -rf /srv/kernel/modules/6.12.62+
else
    echo "OK: /srv/kernel/modules/6.12.62+ already removed"
fi

# 4. Remove invalid staged DTBs
if ls /srv/kernel/dtbs/*6.12* >/dev/null 2>&1 ; then
    echo "Removing staged 6.12 DTBs"
    rm -f /srv/kernel/dtbs/*6.12*
else
    echo "OK: No staged 6.12 DTBs found"
fi

# 5. Remove invalid staged zImage
if [ -f /srv/kernel/boot/zImage ] ; then
    if grep -q "6.12" /srv/kernel/VERSION 2>/dev/null ; then
        echo "Removing staged 6.12 zImage"
        rm -f /srv/kernel/boot/zImage
    else
        echo "OK: zImage does not belong to 6.12"
    fi
else
    echo "OK: No staged zImage found"
fi

# 6. Remove invalid VERSION file
if [ -f /srv/kernel/VERSION ] ; then
    if grep -q "6.12" /srv/kernel/VERSION ; then
        echo "Removing 6.12 VERSION file"
        rm -f /srv/kernel/VERSION
    else
        echo "OK: VERSION file is not 6.12"
    fi
else
    echo "OK: No VERSION file found"
fi

echo "== Clean-house complete =="
exit 0
