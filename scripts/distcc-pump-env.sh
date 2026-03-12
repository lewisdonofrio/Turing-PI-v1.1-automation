export DISTCC_HOSTS="$(grep -E '^[ ]*-[ ]+[A-Za-z0-9]' "/opt/ansible-k3s-cluster/manifest/distcc-hosts.yml" | awk '{print $2}')"
export DISTCC_VERBOSE=0
# Add any other pump/distcc env exports here as needed.
