echo "=== Quickcheck: distcc hostfile ==="
grep -E '^[ ]*-[ ]+[A-Za-z0-9]' /opt/ansible-k3s-cluster/manifest/distcc-hosts.yml | awk '{print $2}'

echo
echo "=== Quickcheck: workers reachable ==="
for h in $(grep -E '^[ ]*-[ ]+[A-Za-z0-9]' /opt/ansible-k3s-cluster/manifest/distcc-hosts.yml | awk '{print $2}'); do
    echo "--- $h ---"
    ssh -o ConnectTimeout=2 $h "echo ok"
done

echo
echo "=== Quickcheck: distccd active ==="
for h in $(grep -E '^[ ]*-[ ]+[A-Za-z0-9]' /opt/ansible-k3s-cluster/manifest/distcc-hosts.yml | awk '{print $2}'); do
    echo "--- $h ---"
    ssh $h "systemctl is-active distccd"
done

echo
echo "=== Quickcheck: distccd listening on 3632 ==="
for h in $(grep -E '^[ ]*-[ ]+[A-Za-z0-9]' /opt/ansible-k3s-cluster/manifest/distcc-hosts.yml | awk '{print $2}'); do
    echo "--- $h ---"
    ssh $h "ss -lntp | grep 3632 || echo 'not listening'"
done

echo
echo "=== Quickcheck: builder toolchain ==="
command -v gcc || echo "gcc missing"
command -v distcc || echo "distcc missing"

echo
echo "=== Quickcheck: stale pump state ==="
pgrep -f include-server && echo "include-server running (should NOT be)" || echo "include-server: none"
ls -d /tmp/distcc-pump.* 2>/dev/null && echo "stale pump dirs exist (should NOT)" || echo "no pump dirs"
