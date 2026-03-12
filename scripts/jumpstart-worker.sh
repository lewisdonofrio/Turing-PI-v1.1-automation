#!/bin/bash
set -euo pipefail

echo "[1/6] Ensuring ansible user exists"
id ansible &>/dev/null || useradd -m -u 1001 -g 1001 -s /bin/bash ansible

echo "[2/6] Ensuring builder user exists"
id builder &>/dev/null || useradd -m -u 1002 -g 1002 -s /bin/bash builder

echo "[3/6] Fixing home directory ownership"
chown -R ansible:ansible /home/ansible
chown -R builder:builder /home/builder

echo "[4/6] Installing Python + sudo"
pacman -Sy --noconfirm python sudo

echo "[5/6] Installing ansible SSH key"
mkdir -p /home/ansible/.ssh
chmod 700 /home/ansible/.ssh
cat >/home/ansible/.ssh/authorized_keys <<EOF
<INSERT YOUR ANSIBLE PUBLIC KEY HERE>
EOF
chmod 600 /home/ansible/.ssh/authorized_keys
chown -R ansible:ansible /home/ansible/.ssh

echo "[6/6] Allow ansible passwordless sudo"
echo "ansible ALL=(ALL) NOPASSWD: ALL" >/etc/sudoers.d/ansible
chmod 440 /etc/sudoers.d/ansible

echo "Jumpstart complete — node is ready for Ansible."
