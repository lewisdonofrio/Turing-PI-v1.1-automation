# =============================================================================
# File: /opt/ansible-k3s-cluster/docs/NETWORK-TOPOLOGY.md
# =============================================================================
# Network Topology
# Physical and Logical Network Layout
# =============================================================================

This document describes the network topology of the Turing PI v1.1 cluster.

===============================================================================
1. Physical Network Layout
===============================================================================

- Turing PI v1.1 backplane
- CM3+ modules connected via onboard switch
- Uplink to external switch or router
- kubenode1 acts as control plane

===============================================================================
2. Logical Network Layout
===============================================================================

All nodes share:
- same subnet
- static or DHCP reservations
- consistent hostnames:
      kubenode1
      kubenode2
      kubenode3
      kubenode4
      kubenode5
      kubenode6
      kubenode7

===============================================================================
3. Required Ports
===============================================================================

SSH:
    22/tcp

k3s:
    6443/tcp (API server)
    8472/udp (VXLAN)
    10250/tcp (kubelet)

distcc:
    3632/tcp

===============================================================================
4. Network Best Practices
===============================================================================

- avoid Wi-Fi
- avoid VLAN complexity
- ensure low latency
- avoid jumbo frames
- ensure stable DHCP or static IPs

===============================================================================
5. Summary
===============================================================================

This topology ensures predictable communication for automation and k3s.

# =============================================================================
# End of File
# =============================================================================
