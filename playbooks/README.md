#
# /opt/ansible-k3s-cluster/playbooks/README.md 
## Distributed kernel build lifecycle (CM3+ orchestrator, x86_64 builder)

This cluster uses a **CM3+ node as the orchestrator** and an **x86_64 host as the actual kernel builder**. The CM3+ does not have enough memory to perform a full kernel build and therefore **never runs the build itself**; it only coordinates the process.

The lifecycle is split into five stages:

1. **power-on.yml**  
   - Boot all nodes.  
   - Ensure SSH connectivity.  
   - Ensure systemd is running.  
   - Ensure required mounts exist.  
   - Ensure networking is correct.

2. **post-power-on-validate.yml**  
   - Runs on CM3+ and workers after power-on.  
   - Validates the distcc hostfile at  
     `/opt/ansible-k3s-cluster/manifest/distcc-hosts.yml`.  
   - Parses and shows expected distcc worker hostnames.  
   - On each worker:
     - Ensures `distccd` is active via `systemctl is-active distccd`.  
     - Ensures port `3632` is listening.  
     - Shows recent distccd log entries if available.  
   - **No pump-mode is started in this stage.**

3. **pump-preflight.yml**  
   - Runs on the CM3+ builder only.  
   - Kills any stale `include-server` processes.  
   - Removes any stale `/tmp/distcc-pump.*` directories.  
   - Summarizes `PATH`, `CC`, `HOSTCC`, and basic toolchain availability (`gcc`, `distcc`).  
   - Prepares the environment so starting pump-mode is safe and deterministic.  
   - **Pump-mode is still not active in this stage.**

4. **pump-start.yml**  
   - Runs on the CM3+ builder only.  
   - Validates the distcc hostfile exists.  
   - Ensures `pumpctl` exists and is executable (e.g. `/home/builder/scripts/pumpctl`).  
   - Writes a small environment file (e.g. `DISTCC_HOSTS`, `DISTCC_VERBOSE`).  
   - Starts `include-server` and gives it time to initialize.  
   - Calls `pumpctl health` to confirm:
     - `include-server` is running.  
     - the pump socket exists.  
   - **Pump-mode is now active.**

5. **kernel-build.yml**  
   - **Runs only on the x86_64 builder**, never on the CM3+.  
   - CM3+ lacks sufficient RAM for an in-tree kernel build; attempting it would cause OOM/failure.  
   - The x86_64 builder performs the actual kernel build using:
     - `distcc` for distributed compilation.  
     - pump-mode for distributed preprocessing.  
   - Distcc workers perform `cc1` work; the builder performs final linking.

In summary:

- The **CM3+ orchestrates** power-on, validation, and pump-mode activation.  
- The **x86_64 host performs** the actual kernel build.  
- Pump-mode and distcc are validated via:
  - Ansible, **before** pump is active.  
  - Scripts like `/home/builder/scripts/distcc-validate.sh`, **after** pump is active.

This separation keeps the system deterministic, memory-safe on the CM3+, and maintainable for future operators.
