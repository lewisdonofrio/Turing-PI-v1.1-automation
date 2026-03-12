#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# Cluster SSH Trust Repair (Builder + Alarm Fallback Edition)
# ============================================================
# Doctrine:
#   - builder is the primary SSH identity for all automation
#   - alarm is used ONLY to repair broken nodes
#   - script must be idempotent and safe to run repeatedly
#   - script must repair nodes to match existing cluster behavior
# ============================================================

NODES=(
  kubenode2.home.lab
  kubenode3.home.lab
  kubenode4.home.lab
  kubenode5.home.lab
  kubenode6.home.lab
  kubenode7.home.lab
)

PUBKEY="$(cat ~/.ssh/id_rsa.pub)"
KNOWN_HOSTS="$HOME/.ssh/known_hosts"

echo "============================================================"
echo "Cluster SSH Trust Repair"
echo "============================================================"
echo

for node in "${NODES[@]}"; do
    echo "---- $node ----"

    # ------------------------------------------------------------
    # 1. Detect host key mismatch
    # ------------------------------------------------------------
    if ssh -o BatchMode=yes -o StrictHostKeyChecking=yes builder@"$node" true 2>&1 | grep -q "REMOTE HOST IDENTIFICATION HAS CHANGED"; then
        echo "Host key mismatch detected — removing stale entry"
        ssh-keygen -R "$node" >/dev/null
    fi

    # ------------------------------------------------------------
    # 2. Refresh host key
    # ------------------------------------------------------------
    echo "Refreshing host key..."
    ssh-keyscan -H "$node" >> "$KNOWN_HOSTS" 2>/dev/null

    # ------------------------------------------------------------
    # 3. Try direct builder login
    # ------------------------------------------------------------
    if ssh -o BatchMode=yes builder@"$node" true 2>/dev/null; then
        echo "SSH key authentication (builder): OK"
        echo
        continue
    fi

    echo "Direct builder login failed — falling back to alarm for repair..."

    # ------------------------------------------------------------
    # 4. Use alarm to repair builder's SSH environment
    # ------------------------------------------------------------
    ssh alarm@"$node" bash -s <<EOF
set -e

# Ensure builder home exists
if [ ! -d /home/builder ]; then
    echo "ERROR: /home/builder missing — builder user may not exist"
    exit 1
fi

# Ensure .ssh directory exists
if [ ! -d /home/builder/.ssh ]; then
    echo "Creating /home/builder/.ssh..."
    sudo mkdir -p /home/builder/.ssh
    sudo chmod 700 /home/builder/.ssh
    sudo chown builder:builder /home/builder/.ssh
else
    echo "/home/builder/.ssh exists — verifying permissions..."
    sudo chmod 700 /home/builder/.ssh
    sudo chown builder:builder /home/builder/.ssh
fi

# Ensure authorized_keys exists
if [ ! -f /home/builder/.ssh/authorized_keys ]; then
    echo "Creating authorized_keys..."
    echo "$PUBKEY" | sudo tee /home/builder/.ssh/authorized_keys >/dev/null
    sudo chmod 600 /home/builder/.ssh/authorized_keys
    sudo chown builder:builder /home/builder/.ssh/authorized_keys
else
    echo "authorized_keys exists — ensuring key is present..."
    sudo grep -q "$PUBKEY" /home/builder/.ssh/authorized_keys || \
        echo "$PUBKEY" | sudo tee -a /home/builder/.ssh/authorized_keys >/dev/null
    sudo chmod 600 /home/builder/.ssh/authorized_keys
    sudo chown builder:builder /home/builder/.ssh/authorized_keys
fi
EOF

    # ------------------------------------------------------------
    # 5. Re-test builder login
    # ------------------------------------------------------------
    if ssh -o BatchMode=yes builder@"$node" true 2>/dev/null; then
        echo "SSH key authentication repaired successfully"
    else
        echo "SSH key authentication still failing — manual intervention required"
    fi

    echo
done

echo "============================================================"
echo "SSH Trust Repair Complete"
echo "============================================================"
