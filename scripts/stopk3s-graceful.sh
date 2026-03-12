#!/usr/bin/env bash
set -euo pipefail

echo "[stopk3s] === k3s emergency stop & cleanup ==="

echo "[stopk3s] Checking tmux panes for containerd-linked processes..."

flagged_panes=""

# List all panes and their PIDs
tmux list-panes -a -F "#{pane_id} #{pane_pid}" | while read pane pid; do
    # Check if the process is in a containerd namespace
    if sudo ls -l /proc/$pid/ns 2>/dev/null | grep -q "containerd"; then
        echo "[stopk3s] WARNING: Pane $pane (PID $pid) is tied to a containerd namespace."
        flagged_panes="$flagged_panes $pane"
    fi
done

if [ -n "${flagged_panes:-}" ]; then
    echo "[stopk3s] The following tmux panes may freeze when shims are killed:"
    echo "          $flagged_panes"
    echo "[stopk3s] Press Ctrl-C to abort, or wait 5 seconds to continue..."
    sleep 5
fi


# 1. Stop services (idempotent)
echo "[stopk3s] Stopping k3s and containerd..."
sudo systemctl stop k3s || true
sudo systemctl stop containerd || true

# 2. Kill orphaned shims
echo "[stopk3s] Killing orphaned containerd shims..."
sudo pkill -9 -f containerd-shim-runc-v2 || true

# 3. Verify nothing k3s/containerd/shim is left
echo "[stopk3s] Verifying no k3s/containerd/shim processes remain..."
ps aux | grep -E "k3s|containerd|shim" | grep -v grep || true

# 4. Clean transient runtime state (safe)
echo "[stopk3s] Cleaning transient runtime state..."
sudo rm -rf /run/k3s/containerd/* || true
sudo rm -rf /run/containerd/* || true
sudo rm -rf /var/lib/cni/networks/* || true
sudo rm -f  /var/lib/rancher/k3s/agent/flannel/networks/* || true

echo "[stopk3s] Node is now QUIET. You can either:"
echo "  - leave it in this state, or"
echo "  - bring it back with: sudo systemctl start containerd && sudo systemctl start k3s"
echo "[stopk3s] ========================================"
