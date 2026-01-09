/opt/ansible-k3s-cluster/pumpsafe/docs/PARALLELISM.md
Pumpsafe Build Parallelism Doctrine
Purpose: Defines all safe, supported, and forbidden -j parallelism values for kernel builds on Raspberry Pi CM3+ hardware. This file exists to prevent 2AM mistakes, runaway load, OOM kills, and unstable builds.

1. Core Principle

Parallelism on Raspberry Pi hardware is cluster-driven, not local-CPU-driven.

Local -j values must respect:
- ARMv7 memory ceilings
- CM3+ thermal limits
- distcc worker throughput
- include_server latency
- pump-mode preprocessing overhead

The cluster provides the speed.
The Pi provides stability.

2. The Golden Value: -j14

Through repeated real-world builds, -j14 emerged as the optimal setting for:
- kernel builds
- pump mode
- distcc fan-out
- stable memory usage
- predictable thermal behavior
- reproducible build times

-j14 is the production standard.

Use this for all real builds:
pump make -j14

or, without pump:
make -j14

3. Experimental Parallelism

Higher values are allowed only in controlled, post-reboot, clean-state experiments.

Experimental ceiling: -j24
pump make -j24

Use only when:
- the node has just rebooted
- you are actively monitoring htop
- you are testing worker saturation or throughput
- you accept the risk of OOM or throttling

This is not a production value.

4. Lower Parallelism for Diagnostics

-j12 is the safe fallback when:
- debugging memory pressure
- validating worker behavior
- isolating include_server latency
- running builds on partially degraded nodes

pump make -j12

This is slower but extremely stable.

5. Forbidden Values

The following are never permitted on CM3+ hardware:
- -j32
- -j48
- desktop-class parallelism
- any value that exceeds the Pi memory or thermal envelope

These settings cause:
- OOM kills
- runaway load averages
- distcc starvation
- include_server collapse
- kernel build failures
- cluster instability

They violate pumpsafe doctrine.

6. Summary Table

Production:   -j14   (fast, stable, reproducible)
Experimental: -j24   (controlled testing only)
Diagnostic:   -j12   (memory-safe debugging)
Forbidden:    -j32+  (unsafe on CM3+)

7. Doctrine Enforcement

All pumpsafe scripts, documentation, and operational playbooks must reflect:
- -j14 as the default
- no high-parallelism flags in examples
- no desktop-class values copied from x86 guides
- cluster parallelism comes from pump + distcc, not local -j

This ensures future maintainers inherit a system that is stable, predictable, reproducible, and aligned with the hardware capabilities.
