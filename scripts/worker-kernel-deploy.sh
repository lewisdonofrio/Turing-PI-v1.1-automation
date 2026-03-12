#!/usr/bin/env bash
set -euo pipefail

# ==============================================================
#  WORKER KERNEL DEPLOYER (builder-side)
#
#  Usage:
#      ./worker-kernel-deploy.sh <worker-hostname> <kernel-tarball>
#
#  Example:
#      ./worker-kernel-deploy.sh kubenode7.home.lab kernel-6.18.1+.tar.gz
#
#  This script:
#    - checks free space on /boot and /
#    - copies the kernel tarball to the worker
#    - extracts into /boot/kernels/<krel>/
#    - extracts modules into /lib/modules/<krel>/
#    - updates /boot/config.txt to point to the new kernel
#    - reboots the worker
#
# ==============================================================

if [[ $# -ne 2 ]]; then
    echo "Usage: $0 <worker-hostname> <kernel-tarball>"
    exit 1
fi

TARGET="$1"
TARBALL="$2"

if [[ ! -f "$TARBALL" ]]; then
    echo "ERROR: Kernel tarball not found: $TARBALL"
    exit 1
fi

echo "=== WORKER KERNEL DEPLOYER ==="
echo "Target node: $TARGET"
echo "Tarball:     $TARBALL"
echo

# --------------------------------------------------------------
# STEP 1: Extract kernelrelease from tarball
# --------------------------------------------------------------
echo "Extracting kernelrelease from tarball..."

KREL=$(tar -xOf "$TARBALL" kernelrelease.txt)
echo "Kernelrelease: $KREL"
echo

# --------------------------------------------------------------
# STEP 2: Check free space on worker
# --------------------------------------------------------------
echo "=== Checking free space on worker ==="

BOOT_FREE=$(ssh "$TARGET" "df -m /boot | awk 'NR==2 {print \$4}'")
ROOT_FREE=$(ssh "$TARGET" "df -m / | awk 'NR==2 {print \$4}'")

echo "Free space on /boot: ${BOOT_FREE} MB"
echo "Free space on /:     ${ROOT_FREE} MB"
echo

MIN_BOOT=50
MIN_ROOT=200

if (( BOOT_FREE < MIN_BOOT )); then
    echo "ERROR: Not enough free space on /boot (need ${MIN_BOOT}MB)"
    exit 1
fi

if (( ROOT_FREE < MIN_ROOT )); then
    echo "ERROR: Not enough free space on / (need ${MIN_ROOT}MB)"
    exit 1
fi

echo "=== Space check passed ==="
echo

# --------------------------------------------------------------
# STEP 3: Copy tarball to worker
# --------------------------------------------------------------
echo "Copying tarball to worker..."
scp "$TARBALL" "$TARGET:/tmp/kernel.tar.gz"
echo "Copy complete."
echo

# --------------------------------------------------------------
# STEP 4: Extract kernel + modules on worker
# --------------------------------------------------------------
echo "Extracting kernel on worker..."

ssh "$TARGET" bash <<EOF
set -euo pipefail

echo "Creating versioned kernel directory..."
mkdir -p /boot/kernels/$KREL

echo "Extracting kernel files..."
tar -xzf /tmp/kernel.tar.gz -C /boot/kernels/$KREL --strip-components=1 boot/

echo "Extracting modules..."
tar -xzf /tmp/kernel.tar.gz -C / --strip-components=1 lib/

echo "Cleaning up..."
rm -f /tmp/kernel.tar.gz

EOF

echo "Extraction complete."
echo

# --------------------------------------------------------------
# STEP 5: Update /boot/config.txt
# --------------------------------------------------------------
echo "Updating /boot/config.txt..."

ssh "$TARGET" bash <<EOF
set -euo pipefail

CONFIG=/boot/config.txt
KERNEL_PATH="/boot/kernels/$KREL/zImage-$KREL"

# Remove any existing kernel= lines
sed -i '/^kernel=/d' "\$CONFIG"

# Add new kernel line
echo "kernel=$KERNEL_PATH" >> "\$CONFIG"

EOF

echo "config.txt updated."
echo

# --------------------------------------------------------------
# STEP 6: Reboot worker
# --------------------------------------------------------------
echo "Rebooting worker..."
ssh "$TARGET" sudo reboot

echo "Deployment complete. Worker is rebooting."
echo "Run your runtime validator after it comes back online."
