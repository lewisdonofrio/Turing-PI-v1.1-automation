#!/bin/sh
# kernel-toolchain-check-and-reset.sh
# Toolchain sanity check + kernel tree reset for native ARMv7 distcc builds

set -e

WORKERS="kubenode2 kubenode3 kubenode4 kubenode5 kubenode6 kubenode7"
KERNEL_DIR="/home/builder/src/kernel"

echo "=== TOOLCHAIN SANITY CHECK (BUILDER) ==="

check_bin() {
    if ! command -v "$1" >/dev/null 2>&1; then
        echo "ERROR: Missing tool: $1"
        exit 1
    else
        echo "OK: $1 found at $(command -v $1)"
    fi
}

# Native ARMv7 toolchain (no CROSS_COMPILE prefix)
REQUIRED_TOOLS="
gcc
ld
as
nm
objcopy
objdump
"

for tool in $REQUIRED_TOOLS; do
    check_bin "$tool"
done

echo "Checking distcc wrapper priority..."
if [ "$(command -v gcc)" != "/usr/lib/distcc/bin/gcc" ]; then
    echo "ERROR: gcc is not routed through distcc wrapper"
    echo "PATH is: $PATH"
    exit 1
else
    echo "OK: gcc is routed through distcc wrapper"
fi

echo "=== TOOLCHAIN SANITY CHECK (WORKERS) ==="

for host in $WORKERS; do
    echo "--- Checking $host ---"

    ssh builder@"$host" "command -v gcc >/dev/null 2>&1"
    if [ $? -ne 0 ]; then
        echo "ERROR: $host missing gcc"
        exit 1
    else
        echo "OK: $host has gcc"
    fi

    ssh builder@"$host" "systemctl is-active distccd >/dev/null 2>&1"
    if [ $? -ne 0 ]; then
        echo "ERROR: distccd not active on $host"
        exit 1
    else
        echo "OK: distccd active on $host"
    fi
done

echo "=== DISTCC CONNECTIVITY TEST ==="

for host in $WORKERS; do
    echo "Testing distcc TCP port on $host..."
    ssh builder@$host "ss -tln | grep -q ':3632 '"
    if [ $? -ne 0 ]; then
        echo "ERROR: Cannot reach distccd on $host:3632"
        exit 1
    else
        echo "OK: distccd reachable on $host:3632"
    fi
done

echo "=== ALL TOOLCHAIN CHECKS PASSED ==="
echo "Proceeding with kernel tree reset..."

echo "Removing old kernel tree..."
rm -rf "$KERNEL_DIR"

echo "Recreating workspace..."
mkdir -p /home/builder/src

echo "Cloning Raspberry Pi kernel..."
git clone --depth=1 https://github.com/raspberrypi/linux.git "$KERNEL_DIR"

echo "Restoring running kernel config..."
zcat /proc/config.gz > "$KERNEL_DIR/.config"

echo "Normalizing config..."
cd "$KERNEL_DIR"

unset MAKEFLAGS
unset CC
unset CXX
unset CROSS_COMPILE

export ARCH=arm
export PATH="/usr/lib/distcc/bin:/usr/lib/distcc:/usr/local/sbin:/usr/local/bin:/usr/bin:/usr/sbin:/sbin:/bin"
export DISTCC_HOSTS="$WORKERS"

echo "Environment prepared:"
echo "  ARCH=$ARCH"
echo "  PATH=$PATH"
echo "  DISTCC_HOSTS=$DISTCC_HOSTS"

make olddefconfig

echo "=== KERNEL TREE READY FOR DISTCC BUILD ==="
echo "Run: cd ~/src/kernel && make -j16 Image modules dtbs"
