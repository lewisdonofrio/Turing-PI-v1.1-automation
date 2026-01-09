Pump Mode Lifecycle - ansible-k3s-cluster
=========================================

Purpose
-------

This directory contains the canonical, cluster-local source and tooling
for distcc pump-mode. Upstream distcc no longer maintains pump-mode,
AUR no longer ships it, and ArchLinuxARM does not provide a working
pump build for Python 3.x on ARMv7.

This tree is treated as the authoritative upstream for pump-mode on this
cluster.

Layout
------

/opt/ansible-k3s-cluster/pumpsafe/
    distcc-pump-src/      - Full distcc + pump-mode source (git tree)
    patches/              - Local patches (GCC, Python, etc.)
    bin/
        pump-restore.sh   - Rebuild and reinstall pump-mode from this tree
        pump-backup.sh    - Archive pumpsafe + installed include_server
    docs/
        README-pump-mode.txt - This file

Key dependencies
----------------

- Python: /usr/bin/python3 (currently Python 3.13)
- Site-packages: /usr/lib/python3.13/site-packages
- C compiler: /usr/bin/gcc
- distcc workers: configured separately via cluster doctrine

Pump restore workflow
---------------------

Whenever Python is upgraded (e.g. 3.13.10 -> 3.13.11), the ABI tag
changes and distcc pump-mode breaks unless rebuilt. To restore pump-mode:

    sudo /opt/ansible-k3s-cluster/pumpsafe/bin/pump-restore.sh

This script will:

    - Reset the distcc-pump-src tree to a clean state (if git present)
    - Apply all patches in patches/*.patch
    - Run autogen.sh (if present)
    - Run ./configure --prefix=/usr --with-python=/usr/bin/python3
    - Run make -j$(nproc)
    - Run make install (installing distcc + pump-mode)
    - Locate include_server under site-packages
    - Locate distcc_pump_c_extensions*.so
    - Create ABI-specific directory:
          /usr/lib/python3.13/site-packages/include_server/c_extensions/build/lib.linux-armv7l-cpython-313
    - Symlink the .so into:
          distcc_pump_c_extensions.cpython-313-arm-linux-gnueabihf.so
    - Start python3 -m include_server.run with /usr/bin/gcc
      and verify it stays running

If the restore script completes successfully, pump-mode is ready.

Backup workflow
---------------

To backup the pumpsafe tree and the currently installed include_server
Python module:

    /opt/ansible-k3s-cluster/pumpsafe/bin/pump-backup.sh

This will create a tarball under:

    /var/backups/pumpsafe/pumpsafe-backup-YYYYMMDD-HHMMSS.tar.gz

This tarball should be included in off-node backups.

Patches
-------

Local patches live under:

    /opt/ansible-k3s-cluster/pumpsafe/patches/*.patch

Do we pull down the repo to ensure to feed updates to - https://github.com/distcc/distcc

These are applied automatically by pump-restore.sh.

Typical patches include:

    - GCC warning fixes (e.g. implicit-fallthrough)
    - Python compatibility adjustments
    - Minor build system corrections

Any new patch should be:

    - Documented with a header in the .patch file
    - Committed to the ansible-k3s-cluster repo
    - Tested via pump-restore.sh on a non-production node

Operational doctrine
--------------------

- Pump-mode is required for efficient distributed kernel builds.
- Pump-mode is tightly coupled to the Python ABI and must be rebuilt
  after Python upgrades.
- This pumpsafe directory is the authoritative source of pump-mode for
  this cluster.
- No external network access or upstream download is required to rebuild
  pump-mode: everything needed is stored here.

If pump-mode fails:
-------------------

1. Check pump-restore logs:

       /var/log/pump-restore/pump-restore-*.log

2. Verify include_server presence:

       /usr/lib/python3.13/site-packages/include_server

3. Verify the C extension symlink:

       /usr/lib/python3.13/site-packages/include_server/c_extensions/build/lib.linux-armv7l-cpython-313/distcc_pump_c_extensions.cpython-313-arm-linux-gnueabihf.so

4. Rerun pump-restore.sh and inspect logs for errors.

If all else fails, restore from the latest pumpsafe-backup tarball and
re-run pump-restore.sh.

End of file.
