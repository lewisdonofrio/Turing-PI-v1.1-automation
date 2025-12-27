# =============================================================================
# File: /opt/ansible-k3s-cluster/docs/SERVICE-RECOVERY.md
# =============================================================================
# Service Recovery Guide
# Procedures for Restoring Failed Services
# =============================================================================

This document provides recovery procedures for common service failures.

===============================================================================
1. k3s Recovery
===============================================================================

Restart service:
    sudo systemctl restart k3s

Check logs:
    sudo journalctl -u k3s -f

===============================================================================
2. distccd Recovery
===============================================================================

Restart distccd:
    sudo systemctl restart distccd

Re-enter builder mode if needed:
    ansible-playbook -i inventory/hosts site.yml -t builder_mode

===============================================================================
3. SSH Recovery
===============================================================================

Fix host keys:
    ssh-keygen -R kubenodeX
    ssh-keyscan -H kubenodeX >> ~/.ssh/known_hosts

===============================================================================
4. Network Recovery
===============================================================================

- verify cabling
- verify switch
- verify IP assignment
- ping between nodes

===============================================================================
5. Summary
===============================================================================

This guide provides quick recovery steps for common service failures.

# =============================================================================
# End of File
# =============================================================================
