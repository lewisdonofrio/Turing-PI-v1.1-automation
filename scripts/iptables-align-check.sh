#!/usr/bin/env bash
set -euo pipefail

echo "== iptables backend alignment check =="

has_pkg() {
  pacman -Qq "$1" &>/dev/null
}

backend="unknown"
if has_pkg iptables-nft; then
  backend="nft"
elif has_pkg iptables; then
  backend="legacy"
fi

echo "Detected backend package: ${backend}"

# If we're already on legacy, we're aligned with the current fleet.
if [[ "$backend" == "legacy" ]]; then
  echo "Status: ALIGNED (legacy iptables). No action required."
  exit 0
fi

# If neither is installed, something is badly wrong.
if [[ "$backend" == "unknown" ]]; then
  echo "Status: ERROR – neither iptables nor iptables-nft installed."
  exit 1
fi

echo "Status: Node is using iptables-nft (nft backend)."

# Check if iproute2 is hard-bound to iptables-nft's libxtables
echo "Checking iproute2 dependency on libxtables from iptables-nft..."
if pacman -Qi iproute2 2>/dev/null | grep -q 'libxtables.so=12-32'; then
  echo
  echo "Result: iproute2 depends on libxtables.so=12-32 from iptables-nft."
  echo "This node is effectively NFT-LOCKED by base dependencies."
  echo
  echo "Safe automated rollback to legacy iptables is NOT possible here."
  echo "Options:"
  echo "  - Reimage this node with a known-good legacy image"
  echo "  - Accept nft backend on this node (or future fleet-wide nft)"
  exit 2
fi

echo
echo "Result: iproute2 is NOT hard-bound to iptables-nft."
echo "In this state, a manual, staged rollback to legacy iptables MAY be possible,"
echo "but it must be done with explicit version pinning and package downgrades."
echo "Automating that safely in a generic script is not recommended."
exit 3
