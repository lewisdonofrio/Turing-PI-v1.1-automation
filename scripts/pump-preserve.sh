#!/bin/sh
# filename: pump-preserve.sh
# purpose: Preserve the canonical pump-mode source tree into /opt/ansible-k3s-cluster/pumpsafe

set -eu

SRC="/home/builder/src/distcc-pump-src"
DEST="/opt/ansible-k3s-cluster/pumpsafe"

echo "==> Creating pumpsafe directory if needed..."
sudo mkdir -p "$DEST"

echo "==> Copying pump-mode source tree..."
sudo rsync -av --delete \
    "$SRC/" \
    "$DEST/distcc-pump-src/"

echo "==> Ensuring patches directory exists..."
sudo mkdir -p "$DEST/patches"

# If you already have patches, copy them:
if [ -d "$SRC/patches" ]; then
    echo "==> Copying patches..."
    sudo rsync -av "$SRC/patches/" "$DEST/patches/"
fi

echo "==> Pump-mode source preserved at: $DEST"
echo "==> Add this directory to your backup rotation."
