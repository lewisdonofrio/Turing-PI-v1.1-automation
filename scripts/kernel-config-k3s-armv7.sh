#!/bin/sh
export PATH=/usr/bin:/usr/local/bin:/usr/sbin:/usr/bin/site_perl:/usr/bin/vendor_perl:/usr/bin/core_perl:$PATH
# /home/builder/scripts/kernel-config-k3s-armv7.sh
# Make the running ARMv7 (armv7l) kernel config k3s-ready in a deterministic way.
#
# Usage (from inside kernel source tree):
#   sh ./kernel-config-k3s-armv7.sh
#
# Assumptions:
#   - You are on the builder.
#   - Kernel source tree matches the running kernel version.
#   - ARCH = arm (32-bit) — armv7l userland.
#   - scripts/config exists (from kernel tree).

set -eu

ARCH_VALUE="arm"

echo "=== k3s kernel config for ARCH=${ARCH_VALUE} ==="

if [ ! -f "Makefile" ] || [ ! -d "scripts" ]; then
    echo "ERROR: This does not look like a kernel source tree (missing Makefile or scripts/)." >&2
    exit 1
fi

if [ ! -x "scripts/config" ]; then
    echo "scripts/config not found; building it..."
    make ARCH="${ARCH_VALUE}" olddefconfig scripts/config
fi

echo "[1/5] Importing running kernel config from /proc/config.gz..."
if [ ! -r /proc/config.gz ]; then
    echo "ERROR: /proc/config.gz not readable. Is CONFIG_IKCONFIG_PROC enabled in the running kernel?" >&2
    exit 1
fi
zcat /proc/config.gz > .config

echo "[2/5] Normalizing .config for ARCH=${ARCH_VALUE}..."
make ARCH="${ARCH_VALUE}" olddefconfig

echo "[3/5] Applying k3s-required options via scripts/config..."

# --- Netfilter core + conntrack + NAT + iptables compat ---
scripts/config --enable CONFIG_NETFILTER
scripts/config --enable CONFIG_NETFILTER_ADVANCED

scripts/config --module CONFIG_NF_CONNTRACK
scripts/config --enable CONFIG_NF_CONNTRACK_PROCFS

scripts/config --module CONFIG_NF_NAT
scripts/config --module CONFIG_NF_NAT_IPV4

scripts/config --module CONFIG_NETFILTER_XTABLES
scripts/config --module CONFIG_NETFILTER_XT_MATCH_COMMENT

scripts/config --module CONFIG_IP_NF_IPTABLES
scripts/config --module CONFIG_IP_NF_FILTER
scripts/config --module CONFIG_IP_NF_MANGLE
scripts/config --module CONFIG_IP_NF_RAW
scripts/config --module CONFIG_IP_NF_TARGET_MASQUERADE

# --- Bridge + bridge netfilter (for CNI / flannel) ---
scripts/config --enable CONFIG_BRIDGE
scripts/config --enable CONFIG_BRIDGE_NETFILTER

# --- OverlayFS (for container filesystems) ---
scripts/config --enable CONFIG_OVERLAY_FS

# --- Control groups (cgroups) ---
scripts/config --enable CONFIG_CGROUPS
scripts/config --enable CONFIG_CGROUP_SCHED
scripts/config --enable CONFIG_FAIR_GROUP_SCHED
scripts/config --enable CONFIG_CFS_BANDWIDTH
scripts/config --enable CONFIG_CGROUP_CPUACCT
scripts/config --enable CONFIG_CGROUP_DEVICE
scripts/config --enable CONFIG_CGROUP_FREEZER
scripts/config --enable CONFIG_CPUSETS
scripts/config --enable CONFIG_MEMCG
scripts/config --enable CONFIG_MEMCG_SWAP
scripts/config --enable CONFIG_MEMCG_KMEM

# --- Namespaces (commonly expected by k8s/k3s userland) ---
scripts/config --enable CONFIG_NAMESPACES
scripts/config --enable CONFIG_UTS_NS
scripts/config --enable CONFIG_IPC_NS
scripts/config --enable CONFIG_USER_NS
scripts/config --enable CONFIG_PID_NS
scripts/config --enable CONFIG_NET_NS

# --- BPF (for networking helpers, kube-proxy, CNIs) ---
scripts/config --enable CONFIG_BPF
scripts/config --enable CONFIG_BPF_SYSCALL
scripts/config --enable CONFIG_BPF_JIT
scripts/config --enable CONFIG_HAVE_EBPF_JIT

# --- VXLAN (used by flannel and other overlays) ---
scripts/config --module CONFIG_VXLAN

echo "[4/5] Normalizing .config again (resolve dependencies)..."
make ARCH="${ARCH_VALUE}" olddefconfig

echo "[5/5] Done. k3s-ready .config written."
echo
echo "Next steps (example):"
echo "  source ~/builder-distcc-env-setup.sh"
echo "  pump --shutdown"
echo "  pump --startup"
echo "  pump make -j24 ARCH=${ARCH_VALUE} CC=\"distcc gcc\" Image modules dtbs"
