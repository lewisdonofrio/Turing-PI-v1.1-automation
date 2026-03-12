#!/usr/bin/env bash
set -euo pipefail

echo "== Kernel & cgroup mode =="
uname -a
echo
mount | grep cgroup || true
echo
echo "cgroup v1 controllers:"
ls -1 /sys/fs/cgroup || true
echo

echo "== k3s check-config =="
sudo k3s check-config || true
echo

echo "== containerd / CRI socket =="
sudo k3s ctr version || echo "ctr failed"
echo
sudo k3s ctr plugins ls || echo "ctr plugins failed"
echo
sudo k3s crictl info || echo "crictl info failed"
echo

echo "== Filesystem sanity =="
df -h /
echo
dmesg | grep -iE "mmc|ext4|i/o error" || echo "no obvious mmc/ext4/i/o errors"
echo

echo "== k3s service status (tail) =="
sudo systemctl status k3s --no-pager -l | tail -n 40
