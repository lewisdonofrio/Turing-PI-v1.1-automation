# =============================================================================
# File: /opt/cluster/docs/MODE-MAP.md
# =============================================================================
# Purpose:
#   Define all operational modes used by the cluster and map each mode to the
#   controlling automation layer (Ansible or local scripts). Provides a clear
#   reference for mode transitions and responsibilities. ASCII-only. Nano-safe.
#   No tabs.
# =============================================================================

# =============================================================================
# ANSIBLE INVENTORY (AUTHORITATIVE)
# =============================================================================
Inventory directory:
/opt/ansible-k3s-cluster/inventory

Inventory file:
/opt/ansible-k3s-cluster/inventory/hosts

All Ansible commands MUST reference this file explicitly:

ansible -i /opt/ansible-k3s-cluster/inventory/hosts all -m ping
ansible-playbook -i /opt/ansible-k3s-cluster/inventory/hosts <playbook>.yml

# =============================================================================
# OVERVIEW
# =============================================================================
The cluster operates in two primary modes:

1. DISTCC BUILD MODE
2. K3S MODE

Mode switching is explicit and controlled.  
Ansible manages cluster-wide state.  
Local scripts manage builder-node environment and kernel build preparation.

# =============================================================================
# MODE: DISTCC BUILD MODE
# =============================================================================
Purpose:
- Enable distributed kernel compilation using distcc.
- Prepare workers and builder node for high-throughput builds.

Controlled by:
- Ansible (cluster-wide)
- Local scripts (builder node)

Ansible responsibilities:
- install distccd on workers
- reset distccd state
- validate distcc cluster
- smoketest distributed compilation
- switch cluster into distcc mode

Local script responsibilities:
- builder-mode.sh
- builder-preflight.sh
- builder-tmpfs-ensure
- PATH and compiler overrides
- tmpfs workspace preparation

Entry sequence:
1. ansible -i /opt/ansible-k3s-cluster/inventory/hosts all -m ping
2. ansible-playbook -i /opt/ansible-k3s-cluster/inventory/hosts playbooks/distccd-bootstrap.yml
3. ansible-playbook -i /opt/ansible-k3s-cluster/inventory/hosts playbooks/distcc-mode-switch.yml
4. ansible-playbook -i /opt/ansible-k3s-cluster/inventory/hosts playbooks/cluster-distcc-validate.yml
5. /opt/cluster/scripts/builder-mode.sh

Exit sequence:
- ansible-playbook -i /opt/ansible-k3s-cluster/inventory/hosts playbooks/cluster-mode-restore.yml

# =============================================================================
# MODE: K3S MODE
# =============================================================================
Purpose:
- Restore cluster workloads and normal service operation.

Controlled by:
- Ansible only

Ansible responsibilities:
- bootstrap k3s (first time only)
- restore cluster mode
- validate k3s cluster
- verify node health
- manage cluster services

Entry sequence:
1. ansible -i /opt/ansible-k3s-cluster/inventory/hosts all -m ping
2. ansible-playbook -i /opt/ansible-k3s-cluster/inventory/hosts playbooks/k3s-bootstrap.yml
3. ansible-playbook -i /opt/ansible-k3s-cluster/inventory/hosts playbooks/cluster-mode-restore.yml
4. ansible-playbook -i /opt/ansible-k3s-cluster/inventory/hosts playbooks/k3s-validate.yml

Exit sequence:
- ansible-playbook -i /opt/ansible-k3s-cluster/inventory/hosts playbooks/distcc-mode-switch.yml

# =============================================================================
# MODE: BUILDER MODE (LOCAL)
# =============================================================================
Purpose:
- Prepare builder node for kernel builds.
- Ensure deterministic environment.

Controlled by:
- Local scripts only

Responsibilities:
- tmpfs workspace
- PATH overrides
- CC/CXX overrides
- distcc wrapper enforcement
- repo validation
- environment validation

Entry:
- /opt/cluster/scripts/builder-mode.sh

Exit:
- exit shell

# =============================================================================
# MODE TRANSITION SUMMARY
# =============================================================================

DISTCC BUILD MODE -> K3S MODE
- ansible-playbook -i /opt/ansible-k3s-cluster/inventory/hosts playbooks/cluster-mode-restore.yml

K3S MODE -> DISTCC BUILD MODE
- ansible-playbook -i /opt/ansible-k3s-cluster/inventory/hosts playbooks/distcc-mode-switch.yml

BUILDER MODE -> normal shell
- exit

# =============================================================================
# END OF FILE
# =============================================================================
