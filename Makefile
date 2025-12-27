# =============================================================================
# File: /opt/ansible-k3s-cluster/Makefile
# =============================================================================

INVENTORY=inventory/hosts

all:
    @echo "Available commands:"
    @echo "  make verify-builder   - Verify builder user, distccd, tmpfs"
    @echo "  make verify-kernel    - Verify kernel version and modules"
    @echo "  make build-kernel     - Run full builder_mode pipeline"
    @echo "  make k3s-mode         - Return cluster to k3s mode"
    @echo "  make deploy           - Deploy built kernel to all nodes"

verify-builder:
    ansible-playbook -i $(INVENTORY) verify_builder.yml

verify-kernel:
    ansible-playbook -i $(INVENTORY) verify_kernel.yml

build-kernel:
    ansible-playbook -i $(INVENTORY) site.yml -t builder_mode

k3s-mode:
    ansible-playbook -i $(INVENTORY) site.yml -t k3s_mode

deploy:
    ansible-playbook -i $(INVENTORY) site.yml -t builder_mode --skip-tags kernel_build
