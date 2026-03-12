#!/usr/bin/env bash
set -euo pipefail

MASTER="kubenode1"
WORKER_SELECTOR='node-role.kubernetes.io/worker=1'
MIN_READY_WORKERS=2
REQUIRED_WORKERS=2
IMAGE_TAR="/home/alarm/kube-proxy-v1.34-armv7-glibc.tar"
CTR_SOCK="/run/k3s/containerd/containerd.sock"
MIN_RAM_MB=300
K3S_CONFIG="/etc/rancher/k3s/config.yaml"

usage() {
  echo "Usage: $0 --on | --off | --forceclean"
  exit 1
}

check_ram() {
  local free_ram
  free_ram=$(awk '/MemAvailable/ {print int($2/1024)}' /proc/meminfo)
  echo "[*] RAM available: ${free_ram} MiB"
  if [ "$free_ram" -lt "$MIN_RAM_MB" ]; then
    echo "[!] Not enough RAM to safely enter jumper mode (need ${MIN_RAM_MB} MiB)"
    exit 1
  fi
}

ensure_image_imported() {
  local node="$1"
  echo "    checking $node"
  ssh "alarm@$node" "
    sudo ctr --address $CTR_SOCK -n k8s.io images ls | grep -q 'kube-proxy:v1.34-armv7-glibc' \
    || sudo ctr --address $CTR_SOCK -n k8s.io images import '$IMAGE_TAR'
  "
}

# --- kube-proxy config toggles in k3s statefile -----------------------------

enable_kube_proxy_in_config() {
  echo "[*] Ensuring kube-proxy is ENABLED in ${K3S_CONFIG}"
  if grep -q '^\s*- kube-proxy' "$K3S_CONFIG"; then
    echo "    kube-proxy already enabled (no disable entry present or already cleaned)"
  else
    # If a disable block exists, remove kube-proxy from it if present
    if grep -q '^\s*disable:' "$K3S_CONFIG"; then
      # Remove any existing kube-proxy line under disable: (defensive)
      sudo sed -i '/^\s*- kube-proxy/d' "$K3S_CONFIG"
      echo "    removed any stale disable entry for kube-proxy"
    fi
  fi
}

disable_kube_proxy_in_config() {
  echo "[*] Ensuring kube-proxy is DISABLED in ${K3S_CONFIG}"
  if grep -q '^\s*disable:' "$K3S_CONFIG"; then
    if grep -q '^\s*- kube-proxy' "$K3S_CONFIG"; then
      echo "    kube-proxy already listed under disable:"
    else
      echo "    adding kube-proxy to existing disable block"
      sudo sed -i '/^\s*disable:/a\  - kube-proxy' "$K3S_CONFIG"
    fi
  else
    echo "    creating disable block with kube-proxy"
    printf '\ndisable:\n  - kube-proxy\n' | sudo tee -a "$K3S_CONFIG" >/dev/null
  fi
}

restart_k3s_and_wait() {
  echo "[*] Restarting k3s to apply kube-proxy config change"
  sudo systemctl restart k3s

  echo "[*] Waiting for API server to become Ready after k3s restart"
  # Simple readiness loop; can be made stricter if desired
  for i in {1..60}; do
    if kubectl get nodes >/dev/null 2>&1; then
      echo "    API server is responding"
      return 0
    fi
    sleep 2
  done
  echo "[!] API server did not become ready in time after k3s restart"
  exit 1
}

# ---------------------------------------------------------------------------

clean_worker_mode_artifacts() {
  echo "[*] Cleaning worker-mode artifacts on master"

  echo "    Killing flannel"
  pkill -9 flanneld 2>/dev/null || true

  echo "    Killing kube-proxy"
  pkill -9 kube-proxy 2>/dev/null || true

  echo "    Killing containerd-shim processes"
  shims=$(pgrep -f "containerd-shim-runc-v2" || true)
  if [ -n "${shims}" ]; then
    echo "      PIDs: ${shims}"
    kill -9 ${shims} || true
  fi

  echo "    Killing pause containers"
  pauses=$(pgrep -f "/pause" || true)
  if [ -n "${pauses}" ]; then
    echo "      PIDs: ${pauses}"
    kill -9 ${pauses} || true
  fi

  echo "    Removing flannel interface if present"
  if ip link show flannel.1 >/dev/null 2>&1; then
    ip link delete flannel.1 || true
  fi

  echo "    Flushing iptables NAT + filter tables"
  iptables -t nat -F || true
  iptables -t filter -F || true

  echo "    Deleting pods scheduled on master"
  pods=$(kubectl get pods -A -o wide | awk '$7=="'"$MASTER"'" {print $1, $2}')
  while read -r ns pod; do
    [ -z "$ns" ] && continue
    echo "      deleting $ns/$pod"
    kubectl delete pod -n "$ns" "$pod" --force --grace-period=0 || true
  done <<< "$pods"

  echo "[*] Worker-mode cleanup complete."
}

jumper_on() {
  echo "[*] Checking RAM before entering jumper mode"
  check_ram

  echo "[*] Ensuring kube-proxy image is imported on all nodes"
  nodes=($(kubectl get nodes --no-headers | awk '{print $1}'))
  for n in "${nodes[@]}"; do
    ensure_image_imported "$n"
  done

  echo "[*] Enabling kube-proxy in k3s config for jumper mode"
  enable_kube_proxy_in_config
  restart_k3s_and_wait

  echo "[*] Removing master NoSchedule taint (enable worker-mode on master)"
  kubectl taint nodes "$MASTER" node-role.kubernetes.io/master:NoSchedule- || true

  echo "[*] Restarting kube-proxy and flannel DaemonSets"
  kubectl -n kube-system  rollout restart ds/kube-proxy || true
  kubectl -n kube-flannel rollout restart ds/kube-flannel-ds

  echo "[*] Waiting for network on master"
  kubectl wait -n kube-flannel  --for=condition=Ready pod -l app=flannel        --timeout=300s
  kubectl wait -n kube-system   --for=condition=Ready pod -l k8s-app=kube-proxy --timeout=300s

  echo "[*] Waiting for at least $MIN_READY_WORKERS Ready workers (with kube-proxy)"
  while :; do
    ready=$(kubectl get nodes -l "$WORKER_SELECTOR" --no-headers 2>/dev/null \
      | awk '$2=="Ready"{c++} END{print c+0}')
    echo "    Ready workers: ${ready:-0}"
    [ "${ready:-0}" -ge "$MIN_READY_WORKERS" ] && break
    sleep 5
  done

  echo "[*] Worker network online. Master is now in full data-plane mode."
}

jumper_off() {
  echo "[*] Checking worker network readiness before removing jumper"

  flannel_nodes=$(kubectl get pods -n kube-flannel -l app=flannel \
    -o jsonpath='{range .items[?(@.status.phase=="Running")]}{.spec.nodeName}{"\n"}{end}' | sort -u)

  # In jumper OFF, we now expect REAL kube-proxy pods on workers (before we disable it again)
  kp_nodes=$(kubectl get pods -n kube-system -l k8s-app=kube-proxy \
    -o jsonpath='{range .items[?(@.status.phase=="Running")]}{.spec.nodeName}{"\n"}{end}' | sort -u)

  ready_workers=$(comm -12 <(echo "$flannel_nodes") <(echo "$kp_nodes") | wc -l)

  echo "    Workers with flannel + kube-proxy Ready: $ready_workers"

  if [ "$ready_workers" -lt "$REQUIRED_WORKERS" ]; then
    echo "[!] Not enough workers with full network stack Ready."
    echo "[!] Need $REQUIRED_WORKERS, have $ready_workers. Aborting jumper removal."
    exit 1
  fi

  echo "[*] Re-applying master NoSchedule taint"
  kubectl taint nodes "$MASTER" node-role.kubernetes.io/master=NoSchedule:NoSchedule --overwrite

  echo "[*] Draining non-system workloads from master"
  kubectl drain "$MASTER" \
    --ignore-daemonsets \
    --delete-emptydir-data \
    --force

  clean_worker_mode_artifacts

  echo "[*] Disabling kube-proxy in k3s config now that jumper is OFF"
  disable_kube_proxy_in_config
  restart_k3s_and_wait

  echo "[*] Control-plane cleanup complete. Master is now pure control-plane."
}

force_clean() {
  echo "[*] FORCE CLEAN: hard reset to pure control-plane state"

  echo "[*] Applying master NoSchedule taint"
  kubectl taint nodes "$MASTER" node-role.kubernetes.io/master=NoSchedule:NoSchedule --overwrite || true

  clean_worker_mode_artifacts

  echo "[*] FORCE CLEAN complete. Master is now safe for jumper --on."
}

case "${1:-}" in
  --on)         jumper_on ;;
  --off)        jumper_off ;;
  --forceclean) force_clean ;;
  *)            usage ;;
esac
