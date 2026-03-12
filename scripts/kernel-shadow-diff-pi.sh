#!/usr/bin/env bash
set -euo pipefail

SHADOW="$1"

echo "== Pi Shadow Diff =="
echo "Shadow-root: $SHADOW"
echo

compare_tree() {
  local live="$1"
  local shadow="$2"
  echo "-- Comparing $live ↔ $shadow"

  comm -3 \
    <(cd "$live" && find . -type f | sort) \
    <(cd "$shadow" && find . -type f | sort) \
    | sed 's/^\t//g' \
    | while read -r path; do
        if [[ -f "$live/$path" && -f "$shadow/$path" ]]; then
          if cmp -s "$live/$path" "$shadow/$path"; then
            : # unchanged, ignore
          else
            echo "CHANGE  $path"
          fi
        elif [[ -f "$shadow/$path" && ! -f "$live/$path" ]]; then
          echo "NEW     $path"
        elif [[ -f "$live/$path" && ! -f "$shadow/$path" ]]; then
          echo "MISSING $path"
        fi
      done
  echo
}

compare_tree /boot "$SHADOW/boot"
compare_tree /lib/modules "$SHADOW/lib/modules"

echo "Review CHANGE/NEW/MISSING before commit."
