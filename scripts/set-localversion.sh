#!/usr/bin/env bash
set -euo pipefail

KDIR="${1:-.}"

echo "Kernel tree: $KDIR"
if [[ ! -d "$KDIR" ]]; then
    echo "ERROR: directory not found"
    exit 1
fi

# Show current version components
echo "Current Makefile version components:"
grep -E '^(VERSION|PATCHLEVEL|SUBLEVEL|EXTRAVERSION)' "$KDIR/Makefile" || true

# Show existing localversion if present
if [[ -f "$KDIR/localversion" ]]; then
    echo "Existing localversion:"
    cat "$KDIR/localversion"
else
    echo "No existing localversion file."
fi

echo
read -p "Apply localversion '-lld'? [y/N] " ans
if [[ "$ans" != "y" ]]; then
    echo "Aborting."
    exit 0
fi

echo "-lld" > "$KDIR/localversion"

echo
echo "localversion applied:"
cat "$KDIR/localversion"

echo
echo "Effective kernel version will be:"
make -sC "$KDIR" kernelrelease || echo "(will resolve after .config exists)"
