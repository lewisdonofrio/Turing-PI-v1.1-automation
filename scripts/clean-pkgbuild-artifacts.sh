#!/bin/bash
# clean-pkgbuild-artifacts.sh — remove nested src/ and pkg/ dirs

ROOT="${1:-.}"

echo "Cleaning PKGBUILD artifacts under: $ROOT"
echo

# Remove all src/ directories
find "$ROOT" \
  -type d \
  -name src \
  -prune \
  -exec echo "Removing: {}" \; \
  -exec rm -rf {} \;

# Remove all pkg/ directories
find "$ROOT" \
  -type d \
  -name pkg \
  -prune \
  -exec echo "Removing: {}" \; \
  -exec rm -rf {} \;

echo
echo "Cleanup complete."
