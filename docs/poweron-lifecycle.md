#
#  /home/builder/docs/poweron-lifecycle.md     
#
+-----------------------------------------------------------+
| 1. power-on.yml                                           |
|   - Boot all nodes                                        |
|   - Ensure SSH                                            |
|   - Ensure systemd                                        |
|   - Ensure mounts                                         |
|   - Ensure networking                                     |
+-----------------------------+
                              |
                              v
+-----------------------------------------------------------+
| 2. post-power-on-validate.yml                             |
|   - Validate workers                                      |
|   - Validate distccd                                      |
|   - Validate port 3632                                    |
|   - Validate logs                                         |
|   - Validate hostfile                                     |
|   - Validate builder toolchain                            |
|   - Validate no stale state                               |
|   - Validate cluster readiness                            |
|   (NO pump-mode yet)                                      |
+-----------------------------+
                              |
                              v
+-----------------------------------------------------------+
| 3. pump-preflight.yml                                     |
|   - Clean builder environment                             |
|   - Remove stale pump dirs                                |
|   - Remove stale include-server                           |
|   - Validate PATH, CC, HOSTCC                             |
|   - Validate tmpfs (if used)                              |
|   - Validate distcc env                                   |
|   (Still NO pump-mode)                                    |
+-----------------------------+
                              |
                              v
+-----------------------------------------------------------+
| 4. pump-start.yml                                         |
|   - Start include-server                                  |
|   - Create pump socket                                    |
|   - Export DISTCC_HOSTS                                   |
|   - Export pump env vars                                  |
|   - pumpctl health                                        |
|   (Pump-mode ACTIVE)                                      |
+-----------------------------+
                              |
                              v
+-----------------------------------------------------------+
| 5. kernel-build.yml                                       |
|   - Runs ONLY on x86_64                                   |
|   - CM3+ NEVER runs this                                  |
|   - CM3+ lacks RAM for kernel                             |
|   - CM3+ acts as orchestrator                             |
|   - Workers do distributed cc1                            |
|   - Builder does final link                               |
+-----------------------------------------------------------+
