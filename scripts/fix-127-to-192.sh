sudo sed -i 's/127.0.0.1/192.168.29.212/g' /etc/rancher/k3s/k3s.yaml
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
