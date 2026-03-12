#!/bin/sh
# kernel-reset.sh - sterile kernel tree reset for CM3+ builds

set -e

echo "Removing old kernel tree..."
rm -rf /home/builder/src/kernel

echo "Recreating workspace..."
mkdir -p /home/builder/src

echo "Cloning Raspberry Pi kernel..."
git clone --depth=1 https://github.com/raspberrypi/linux.git /home/builder/src/kernel

echo "Restoring running kernel config..."
zcat /proc/config.gz > /home/builder/src/kernel/.config

echo "Normalizing config..."
cd /home/builder/src/kernel

# Clean up dangerous environment variables
unset MAKEFLAGS
unset CC
unset CXX

# Enforce distcc-first environment
export ARCH=arm
export CROSS_COMPILE=armv7l-unknown-linux-gnueabihf-
export PATH="/usr/lib/distcc/bin:/usr/lib/distcc:/usr/local/sbin:/usr/local/bin:/usr/bin:/usr/sbin:/sbin:/bin"
export DISTCC_HOSTS="kubenode2 kubenode3 kubenode4 kubenode5"

echo "Environment prepared:"
echo "  ARCH=$ARCH"
echo "  CROSS_COMPILE=$CROSS_COMPILE"
echo "  PATH=$PATH"
echo "  DISTCC_HOSTS=$DISTCC_HOSTS"

make olddefconfig

echo "Kernel tree and environment ready for distcc build."
echo "Run: cd ~/src/kernel && make -j14 Image modules dtbs"
