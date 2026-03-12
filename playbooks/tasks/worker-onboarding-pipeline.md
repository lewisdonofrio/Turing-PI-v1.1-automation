# Worker Onboarding Pipeline (ASCII Diagram)

This document describes the full, integrated onboarding pipeline for
k3s worker nodes. It reflects the canonical sequence used by the
Ansible playbooks:

    00-reset-worker.yml
    01-verify-kernel.yml
    02-install-k3s-binary.yml
    03-preload-kube-proxy.yml
    04-install-systemd.yml
    04a-ensure-cni.yml   (self-healing CNI repair)
    05-install-delay.yml
    06-start-agent.yml
    07-assert-cni.yml    (strict readiness)

All steps are deterministic, idempotent, and doctrine-aligned.


======================================================================
1. High-Level Pipeline Overview
======================================================================

The worker onboarding pipeline follows this flow:

    +------------------+
    | 00: Reset Worker |
    +------------------+
              |
              v
    +---------------------------+
    | 01: Verify Kernel & CGroups |
    +---------------------------+
              |
              v
    +---------------------------+
    | 02: Install k3s Binary   |
    +---------------------------+
              |
              v
    +---------------------------+
    | 03: Preload kube-proxy   |
    +---------------------------+
              |
              v
    +---------------------------+
    | 04: Install Systemd Unit |
    +---------------------------+
              |
              v
    +-------------------------------------------+
    | 04a: Ensure Embedded CNI (Self-Healing)   |
    | - Remove stray CNI dirs                   |
    | - Verify checksum vs master               |
    | - Repair embedded CNI bundle if needed    |
    | - Recreate /opt/cni/bin symlink           |
    +-------------------------------------------+
              |
              v
    +---------------------------+
    | 05: Install Delay Drop-in |
    +---------------------------+
              |
              v
    +---------------------------+
    | 06: Start Agent          |
    +---------------------------+
              |
              v
    +-------------------------------------------+
    | 07: Assert CNI + Flannel + Node Readiness |
    | - Checksum match                          |
    | - Loopback plugin OK                      |
    | - Containerd loads CNI                    |
    | - flannel.1 exists                        |
    | - kube-proxy running                      |
    | - Node Ready                              |
    +-------------------------------------------+


======================================================================
2. Detailed Step Descriptions
======================================================================

----------------------------------------------------------------------
00-reset-worker.yml
----------------------------------------------------------------------
Optional full reset. Removes:

    /var/lib/rancher/k3s
    /etc/systemd/system/k3s-agent.service
    /etc/systemd/system/k3s-agent.service.d
    /opt/cni
    /etc/cni
    /var/lib/cni

Used when force_rejoin=true.


----------------------------------------------------------------------
01-verify-kernel.yml
----------------------------------------------------------------------
Ensures:

    - Correct kernel version
    - Required modules loaded
    - cgroup v1/v2 compatibility
    - sysctl settings


----------------------------------------------------------------------
02-install-k3s-binary.yml
----------------------------------------------------------------------
Installs the correct ARMv7 k3s binary into:

    /usr/local/bin/k3s

Ensures correct permissions and version pinning.


----------------------------------------------------------------------
03-preload-kube-proxy.yml
----------------------------------------------------------------------
Loads the canonical kube-proxy image into containerd:

    kube-proxy:v1.34-armv7-glibc

Ensures kube-proxy is available before agent start.


----------------------------------------------------------------------
04-install-systemd.yml
----------------------------------------------------------------------
Installs:

    /etc/systemd/system/k3s-agent.service
    /etc/systemd/system/k3s-agent.service.env

Ensures deterministic startup behavior.


----------------------------------------------------------------------
04a-ensure-cni.yml (Self-Healing CNI)
----------------------------------------------------------------------
This is the critical CNI repair stage. It:

    - Removes stray CNI directories
    - Ensures /var/lib/rancher/k3s/agent/etc/cni/net.d exists
    - Ensures /opt/cni exists
    - Retrieves master CNI checksum
    - Retrieves worker CNI checksum
    - Compares checksums
    - If mismatched or missing:
        * Removes worker embedded CNI bundle
        * Copies master embedded CNI bundle
    - Recreates /opt/cni/bin -> embedded CNI symlink

This guarantees all workers use the same embedded CNI bundle.


----------------------------------------------------------------------
05-install-delay.yml
----------------------------------------------------------------------
Installs:

    /etc/systemd/system/k3s-agent.service.d/10-delay.conf

Adds ExecStartPre sleep to avoid DNS/systemd race conditions.


----------------------------------------------------------------------
06-start-agent.yml
----------------------------------------------------------------------
Starts the k3s-agent service and verifies:

    systemctl is-active k3s-agent == active


----------------------------------------------------------------------
07-assert-cni.yml (Strict Readiness)
----------------------------------------------------------------------
Performs final readiness checks:

    - CNI checksum matches master
    - loopback plugin exists
    - loopback plugin executable
    - loopback plugin architecture is ELF
    - containerd loads CNI plugins
    - flannel.1 interface exists
    - kube-proxy running on this node
    - Node Ready condition == True

If any check fails, the playbook stops.


======================================================================
3. End-to-End Flow Summary
======================================================================

The onboarding pipeline ensures:

    - Kernel is correct
    - k3s binary is correct
    - kube-proxy is preloaded
    - systemd is deterministic
    - CNI is repaired and aligned with master
    - Agent starts cleanly
    - Node becomes Ready

This produces a stable, reproducible, doctrine-aligned worker.


======================================================================
4. Notes
======================================================================

This pipeline is designed for:

    - ARMv7 workers
    - Embedded CNI only
    - Deterministic cluster convergence
    - Zero drift between workers
    - Self-healing CNI corruption

