bash -c '
set -e
echo "== API =="
curl -ks https://127.0.0.1:6444/readyz && echo "API: ready" || echo "API: NOT ready"

echo; echo "== Nodes =="
kubectl get nodes -o wide

echo; echo "== Workers 3/4/5 node view =="
kubectl get nodes -o wide | egrep "kubenode[345]\.home\.lab" || echo "workers 3/4/5 not registered"

echo; echo "== k3s-agent systemd status =="
for n in kubenode3.home.lab kubenode4.home.lab kubenode5.home.lab; do
  echo "--- $n ---"
  ssh "$n" "systemctl is-active --quiet k3s-agent && echo k3s-agent: active || echo k3s-agent: NOT active"
done

echo; echo "== CNI / flannel presence =="
for n in kubenode3.home.lab kubenode4.home.lab kubenode5.home.lab; do
  echo "--- $n ---"
  ssh "$n" "sudo test -f /var/lib/rancher/k3s/agent/etc/cni/net.d/10-flannel.conflist && echo CNI: flannel present || echo CNI: flannel MISSING"
done

echo; echo "== CoreDNS =="
kubectl -n kube-system get pods -l k8s-app=kube-dns

echo; echo "== kube-proxy on 3/4/5 =="
kubectl -n kube-system get pods -l k8s-app=kube-proxy -o wide | egrep "kubenode[345]\.home\.lab" || echo "no kube-proxy pods on 3/4/5"
'
