#!/bin/sh
# worker-toolchain-bootstrap.sh
# Install cross-compiler + distccd on worker nodes

set -e

echo "Installing toolchain and distccd..."
sudo pacman -Sy --noconfirm \
    armv7l-unknown-linux-gnueabihf-binutils \
    armv7l-unknown-linux-gnueabihf-gcc \
    distcc

echo "Enabling distccd..."
sudo systemctl enable distccd
sudo systemctl start distccd

echo "Verifying distccd..."
systemctl is-active distccd >/dev/null 2>&1 && echo "distccd active"

echo "Worker toolchain ready."
