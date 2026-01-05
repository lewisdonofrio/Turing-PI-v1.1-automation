# /opt/ansible-k3s-cluster/docs/POWERON.md
# Cluster BUILD MODE Orchestration
# --------------------------------
# This document defines the authoritative procedure for preparing the
# Raspberry Pi CM3+/CM4 cluster for distributed kernel builds using distcc
# and pump mode. This replaces all legacy bootstrap steps.

## Purpose
The poweron.yml orchestration playbook transitions the cluster into
BUILD MODE after any cold reboot, power loss, or hardware reseat. It
ensures a deterministic, reproducible environment for distributed kernel
compilation.

## What POWERON Does
The orchestration performs the following steps in order:

1. Reset worker distccd state
2. Apply distccd configuration fixes
3. Switch cluster into distcc build mode
4. Validate cluster-wide distcc readiness
5. Run a cluster-wide distcc smoketest
6. Prepare the builder node:
   - Stop k3s-server
   - Ensure tmpfs mount exists
   - Start distccd
   - Export pump mode environment
   - Apply PATH overrides

## When To Run POWERON
Run poweron.yml after:
- Any full cluster reboot
- Any power loss event
- Any hardware reseat
- Any time the cluster must enter BUILD MODE

## How To Run POWERON
From kubenode1:

    ansible-playbook -i inventory/hosts playbooks/poweron.yml

## Expected Results
- distccd active on all workers
- tmpfs mounted on all nodes
- builder in pump-ready state
- cluster validated and smoketested
- ready for: pump make -j14

## Notes
- distccd-bootstrap.yml is legacy provisioning only.
- poweron.yml is the single authoritative entry point for BUILD MODE.
