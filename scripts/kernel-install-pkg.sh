#!/bin/bash
set -euo pipefail

PKGDIR="$HOME/pkg"
NEWVER="6.18.1+"

BACKUP_ROOT="$HOME/backups/kernel-$(hostname)-$(date +%Y%m%d-%H%M%S)"
echo "BACKUP: creating $BACKUP_ROOT"
mkdir -p "$BACKUP_ROOT"

echo "BACKUP: /boot -> $BACKUP_ROOT/boot"
cp -a /boot "$BACKUP_ROOT/boot"

if [ -d "/usr/lib/modules/$(uname -r)" ]; then
  echo "BACKUP: /usr/lib/modules/$(uname -r) -> $BACKUP_ROOT/modules"
  cp -a "/usr/lib/modules/$(uname -r)" "$BACKUP_ROOT/modules"
else
  echo "WARN: no /usr/lib/modules/$(uname -r) to back up"
fi

echo "INSTALL: copying boot files from $PKGDIR/boot to /boot"
cp -av "$PKGDIR/boot/"* /boot/

echo "INSTALL: installing modules to /usr/lib/modules/$NEWVER"
rm -rf "/usr/lib/modules/$NEWVER"
cp -a "$PKGDIR/usr/lib/modules/$NEWVER" /usr/lib/modules/

echo "CONFIG: ensuring kernel7.img is selected in /boot/config.txt"
if grep -q '^kernel=' /boot/config.txt; then
  sed -i 's|^kernel=.*|kernel=kernel7.img|' /boot/config.txt
else
  echo 'kernel=kernel7.img' >> /boot/config.txt
fi

echo "DONE: new kernel staged as $NEWVER"
echo "Reboot when ready, then check: uname -r"
