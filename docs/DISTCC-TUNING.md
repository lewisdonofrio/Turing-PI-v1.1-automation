# =============================================================================
# File: /opt/ansible-k3s-cluster/docs/DISTCC-TUNING.md
# =============================================================================
# distcc Tuning Guide
# Performance Optimization for Distributed Compilation
# =============================================================================

This document provides tuning recommendations for maximizing distcc performance
across the Turing PI v1.1 cluster.

===============================================================================
1. CPU Core Allocation
===============================================================================

Each CM3+ module has limited CPU resources. Recommended settings:

- distccd jobs per node: 2
- local jobs on kubenode1: 2
- total parallelism: number_of_nodes * 2

===============================================================================
2. Network Considerations
===============================================================================

distcc performance depends heavily on network throughput.

Recommendations:
- use wired Ethernet only
- avoid Wi-Fi
- ensure switch is not oversubscribed
- avoid jumbo frames

===============================================================================
3. tmpfs Usage
===============================================================================

tmpfs dramatically improves performance by:
- reducing SD card I/O
- increasing compile speed
- ensuring clean build trees

Ensure tmpfs is mounted before builds.

===============================================================================
4. Compiler Caching
===============================================================================

ccache is NOT recommended for kernel builds due to:
- large object sizes
- low cache hit rates
- increased RAM usage

distcc alone is preferred.

===============================================================================
5. Load Balancing
===============================================================================

distcc automatically balances jobs across nodes. To improve performance:
- ensure all nodes are reachable
- ensure all nodes have identical toolchains
- avoid running k3s workloads during builds

===============================================================================
6. Summary
===============================================================================

These tuning guidelines ensure optimal distributed compilation performance.

# =============================================================================
# End of File
# =============================================================================
