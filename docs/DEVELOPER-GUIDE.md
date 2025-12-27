# =============================================================================
# File: /opt/ansible-k3s-cluster/docs/DEVELOPER-GUIDE.md
# =============================================================================
# Developer Guide
# How to Extend, Modify, and Maintain the Automation Framework
# =============================================================================

This guide explains how to safely modify and extend the automation repository.

===============================================================================
1. Repository Structure
===============================================================================

- inventory/hosts
- inventory/group_vars/
- roles/
- site.yml
- verify_*.yml
- docs/
- artifacts/

===============================================================================
2. Adding New Roles
===============================================================================

1. Create directory:
       roles/new_role/
2. Add tasks:
       roles/new_role/tasks/main.yml
3. Add handlers if needed
4. Reference role in site.yml

===============================================================================
3. Modifying Existing Roles
===============================================================================

Rules:
- Never break idempotency
- Always test with:
      ansible-playbook --check
- Document changes in docs/

===============================================================================
4. Adding New Playbooks
===============================================================================

1. Create file:
       new_playbook.yml
2. Define hosts and tasks
3. Test with --check
4. Commit and push

===============================================================================
5. Adding New Documentation
===============================================================================

Place all docs in:
    docs/

Use ASCII-only formatting.

===============================================================================
6. Summary
===============================================================================

This guide provides the foundation for extending the automation system safely.

# =============================================================================
# End of File
# =============================================================================
