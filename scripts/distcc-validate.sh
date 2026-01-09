#!/bin/bash
# /home/builder/scripts/distcc-validate.sh
# Purpose: Validate pump-mode and distcc readiness across builder and workers.
# Behavior: Read-only checks for include-server, pump socket, pumpctl, distccd,
#           worker reachability, cc1 activity, and a distributed compile dry-run.
# Notes: ASCII-only. No tabs. Idempotent. Safe to run at any time.

set -e

echo "============================================================"
echo "Distcc + Pump-Mode Validation"
echo "============================================================"
echo

# ---------------------------------------------------------------------------
# Pump-mode checks (builder only)
# ---------------------------------------------------------------------------
echo "[Builder] Pump-mode checks"

if pgrep -f include-server >/dev/null 2>&1; then
    echo "include-server: running"
else
    echo "include-server: NOT running"
fi

PUMP_DIR=$(ls -td /tmp/distcc-pump.* 2>/dev/null | head -n1)
if [ -n "$PUMP_DIR" ]; then
    echo "pump socket dir: $PUMP_DIR"
    if [ -S "$PUMP_DIR/socket" ]; then
        echo "pump socket: present"
    else
        echo "pump socket: MISSING"
    fi
else
    echo "pump socket dir: none"
fi

if /home/builder/scripts/pumpctl health >/dev/null 2>&1; then
    echo "pumpctl health: OK"
else
    echo "pumpctl health: FAILED"
fi

echo

# ---------------------------------------------------------------------------
# Worker list (clean hostnames only)
# ---------------------------------------------------------------------------
HOSTFILE="/opt/ansible-k3s-cluster/manifest/distcc-hosts.yml"

# Match only lines like: "- kubenode2.home.lab"
WORKERS=$(grep -E '^\s*-\s+[a-zA-Z0-9]' "$HOSTFILE" | awk '{print $2}')

echo "[Cluster] Workers:"
echo "$WORKERS"
echo

# ---------------------------------------------------------------------------
# Worker distccd checks
# ---------------------------------------------------------------------------
echo "[Workers] distccd checks"

for w in $WORKERS; do
    echo "---- $w ----"
    ssh "$w" "systemctl is-active distccd || echo 'distccd inactive'"
    ssh "$w" "ss -lntp | grep 3632 || echo 'not listening'"
    ssh "$w" "pgrep -a cc1 || echo 'no cc1 activity'"
    ssh "$w" "tail -n 5 /var/log/distccd/distccd.log 2>/dev/null || echo 'no log'"
    echo
done

# ---------------------------------------------------------------------------
# Distributed compile dry-run
# ---------------------------------------------------------------------------
echo "[Builder] Distributed compile dry-run"

TMPDIR="/tmp/distcc-validate"
mkdir -p "$TMPDIR"

cat > "$TMPDIR/test.c" <<EOF
int main(void) { return 0; }
EOF

OUT=$(
    DISTCC_VERBOSE=1 \
    distcc -j 8 -c "$TMPDIR/test.c" -o "$TMPDIR/test.o" 2>&1
)

echo "$OUT"
echo

# Worker participation
echo "[Analysis] Worker participation:"
echo "$OUT" | grep -oE '[^ ]+:3632' | sed 's/:3632//' | sort | uniq
echo

# Fallback detection
if echo "$OUT" | grep -q "localhost"; then
    echo "Fallback: YES (builder compiled locally)"
else
    echo "Fallback: NO"
fi

echo
echo "Validation complete."
