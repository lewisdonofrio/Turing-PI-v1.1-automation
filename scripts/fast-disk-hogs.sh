#!/bin/bash
# fast-disk-hogs.sh — RPi-friendly disk forensics

set -e

echo "== Top-level directories =="
sudo du -xh --max-depth=1 / 2>/dev/null | sort -h

echo
echo "== /home breakdown =="
sudo du -xh --max-depth=1 /home 2>/dev/null | sort -h

echo
echo "== /usr breakdown =="
sudo du -xh --max-depth=1 /usr 2>/dev/null | sort -h

echo
echo "== /var breakdown =="
sudo du -xh --max-depth=1 /var 2>/dev/null | sort -h

echo
echo "== Large files (>500MB) =="
sudo find / \
  -xdev \
  -type f \
  -size +500M \
  -not -path "/proc/*" \
  -not -path "/sys/*" \
  -not -path "/run/*" \
  -not -path "/tmp/*" \
  -exec ls -lh {} \; 2>/dev/null
