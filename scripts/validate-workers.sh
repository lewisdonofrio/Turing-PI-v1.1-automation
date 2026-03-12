#!/bin/bash
set -euo pipefail

NODES=("kubenode3.home.lab" "kubenode4.home.lab" "kubenode5.home.lab")

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

pass() { echo -e "${GREEN}[PASS]${NC} $1"; }
fail() { echo -e "${RED}[FAIL]${NC} $1"; exit 1; }

echo "=== Validating worker nodes: ${NODES[*]} ==="

# 1. Node Ready state
echo "Checking node readiness..."
for n in "${NODES[@]}"; do
    if kubectl get nodes "$n" 2>/dev/null | grep -q " Ready "; then
        pass "$n is Ready"
    else
        fail "$n is NOT Ready"
    fi
done

# 2. kube-proxy running
echo "Checking kube-proxy pods..."
for n in "${NODES[@]}"; do
    if kubectl -n kube-system get pods -o wide | grep kube-proxy | grep -q "$n"; then
        pass "kube-proxy running on $n"
    else
        fail "kube-proxy NOT running on $n"
    fi
done

# 3. flannel DaemonSet health
echo "Checking flannel DaemonSet..."
FLANNEL=$(kubectl -n kube-system get ds/flannel -o jsonpath='{.status.numberReady}')
if [[ "$FLANNEL" -ge 3 ]]; then
    pass "flannel DaemonSet has $FLANNEL ready pods"
else
    fail "flannel DaemonSet not fully ready ($FLANNEL ready)"
fi

# 4. CNI config presence
echo "Checking CNI config on nodes..."
for n in "${NODES[@]}"; do
    if ssh "$n" "test -f /var/lib/rancher/k3s/agent/etc/cni/net.d/10-flannel.conflist"; then
        pass "CNI config present on $n"
    else
        fail "CNI config missing on $n"
    fi
done

# 5. flannel.1 and cni0 interfaces
echo "Checking flannel and CNI interfaces..."
for n in "${NODES[@]}"; do
    if ssh "$n" "ip link show flannel.1 >/dev/null 2>&1"; then
        pass "flannel.1 exists on $n"
    else
        fail "flannel.1 missing on $n"
    fi

    if ssh "$n" "ip addr show cni0 >/dev/null 2>&1"; then
        pass "cni0 exists on $n"
    else
        fail "cni0 missing on $n"
    fi
done

# 6. CoreDNS running
echo "Checking CoreDNS..."
if kubectl -n kube-system get pods -l k8s-app=kube-dns | grep -q "Running"; then
    pass "CoreDNS is running"
else
    fail "CoreDNS is NOT running"
fi

# 7. local-path-provisioner running
echo "Checking local-path-provisioner..."
if kubectl -n kube-system get pods -l app=local-path-provisioner | grep -q "Running"; then
    pass "local-path-provisioner is running"
else
    fail "local-path-provisioner is NOT running"
fi

# 8. DNS test inside a pod
echo "Testing DNS resolution..."
if kubectl run -it --rm dns-test --image=busybox --restart=Never -- nslookup kubernetes.default >/dev/null 2>&1; then
    pass "DNS resolution works inside pods"
else
    fail "DNS resolution FAILED inside pods"
fi

# 9. Check for stuck pods
echo "Checking for stuck pods..."
if kubectl get pods -A | grep -v Running | grep -v Completed | grep -q .; then
    fail "Some pods are not Running or Completed"
else
    pass "No stuck pods"
fi

echo -e "\n${GREEN}All validation checks passed for worker3/4/5.${NC}"
