#!/bin/bash
set -e

echo "==> Stopping k3s"
sudo systemctl stop k3s || true

echo "==> Stopping containerd"
sudo systemctl stop containerd || true

echo "==> Killing leftover containerd-shim processes"
sudo pkill -f containerd-shim || true

echo "==> Removing ALL CNI binaries (Arch installs these automatically)"
sudo rm -rf /opt/cni/bin/*
sudo rm -rf /usr/lib/cni/*

echo "==> Removing ALL CNI configs"
sudo rm -rf /etc/cni/net.d/*

echo "==> Removing ALL CNI state"
sudo rm -rf /var/lib/cni/*

echo "==> Removing ALL k3s state (forces clean bootstrap)"
sudo rm -rf /var/lib/rancher/k3s

echo "==> Removing leftover network namespaces"
sudo rm -rf /var/run/netns/* || true

echo "==> Restarting containerd clean"
sudo systemctl start containerd

echo "==> Starting k3s fresh"
sudo systemctl start k3s

echo "==> Waiting 10 seconds for k3s to write manifests"
sleep 10

echo "==> Checking for flannel.yaml"
sudo ls -l /var/lib/rancher/k3s/server/manifests | grep flannel || echo "flannel.yaml not found yet"
