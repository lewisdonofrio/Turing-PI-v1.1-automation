#!/bin/sh
#
# kernel-tree-sanity-check.sh
#
# Purpose:
#   Validate integrity of the Raspberry Pi ARMv7 kernel source tree.
#   Ensures required directories and header files exist before any build.
#   Detects incomplete clones, corrupted trees, or missing generated headers.
#
# Usage:
#   /home/builder/scripts/kernel-tree-sanity-check.sh
#
# Notes:
#   - ASCII-only, nano-safe, idempotent.
#   - Safe to run at any time.
#   - Exits non-zero on failure.
#

KERNEL_TREE="/home/builder/src/kernel"

echo "=== kernel-tree-sanity-check.sh ==="
echo "Checking kernel tree at: $KERNEL_TREE"
echo

# 1. Verify kernel tree exists
if [ ! -d "$KERNEL_TREE" ]; then
    echo "ERROR: Kernel tree not found at $KERNEL_TREE"
    exit 1
fi

# 2. Required top-level directories
REQUIRED_DIRS="
include
include/linux
include/uapi
arch/arm
arch/arm/include
arch/arm/include/asm
kernel
drivers
scripts
"

echo "Checking required directories..."
for d in $REQUIRED_DIRS; do
    if [ ! -d "$KERNEL_TREE/$d" ]; then
        echo "ERROR: Missing directory: $KERNEL_TREE/$d"
        exit 1
    fi
done
echo "Directories OK."
echo

# 3. Required core header files
REQUIRED_HEADERS="
include/linux/irq_work.h
arch/arm/include/asm/irq_work.h
include/linux/perf_event.h
include/linux/sched.h
include/linux/mm.h
include/linux/fs.h
"

echo "Checking required header files..."
for f in $REQUIRED_HEADERS; do
    if [ ! -f "$KERNEL_TREE/$f" ]; then
        echo "ERROR: Missing header: $KERNEL_TREE/$f"
        exit 1
    fi
done
echo "Header files OK."
echo

# 4. Check generated headers directory (created by prepare)
if [ ! -d "$KERNEL_TREE/include/generated" ]; then
    echo "WARNING: include/generated is missing."
    echo "This usually means 'make prepare' has not been run yet."
    echo "This is not fatal, but will be fatal during build."
    echo
else
    # Check for generated/uapi
    if [ ! -d "$KERNEL_TREE/include/generated/uapi" ]; then
        echo "ERROR: include/generated/uapi is missing."
        echo "Tree is incomplete or corrupted."
        exit 1
    fi
fi

echo "Generated headers OK (or not yet generated)."
echo

# 5. Check for Raspberry Pi-specific directories
RPI_DIRS="
arch/arm/boot/dts
arch/arm/configs
drivers/gpu/drm
drivers/net
drivers/scsi
"

echo "Checking Raspberry Pi-specific directories..."
for d in $RPI_DIRS; do
    if [ ! -d "$KERNEL_TREE/$d" ]; then
        echo "ERROR: Missing Raspberry Pi directory: $KERNEL_TREE/$d"
        exit 1
    fi
done
echo "Raspberry Pi directories OK."
echo

echo "Kernel tree sanity check PASSED."
echo "==============================================="
exit 0
