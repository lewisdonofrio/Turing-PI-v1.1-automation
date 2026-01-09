#!/bin/bash
set -euo pipefail

LOG="/home/builder/build-logs/pump-fitness.log"

# Timestamp every line and append to log
exec > >(while IFS= read -r line; do
    printf "[%s] %s\n" "$(date -u +"%Y-%m-%d %H:%M:%S")" "$line"
done | tee -a "$LOG") 2>&1

echo "[pump-fitness] Starting fitness check"

# ------------------------------------------------------------
# 1. Python package import
# ------------------------------------------------------------
echo "[pump-fitness] Checking include_server Python package..."
python3 - <<'EOF'
import include_server
print("  OK: include_server imported")
EOF

# ------------------------------------------------------------
# 2. C extension load
# ------------------------------------------------------------
echo "[pump-fitness] Checking C extension..."
python3 - <<'EOF'
from include_server import c_extensions
print("  OK: C extension loaded")
EOF

# ------------------------------------------------------------
# 3. include_server.py executable
# ------------------------------------------------------------
echo "[pump-fitness] Checking include_server.py executable..."
INC="/usr/lib/python3.13/site-packages/include_server/include_server.py"
if [[ ! -x "$INC" ]]; then
    echo "ERROR: include_server.py is not executable: $INC"
    exit 1
fi
echo "  OK: include_server.py is executable"

# ------------------------------------------------------------
# 4. Wrapper precedence
# ------------------------------------------------------------
echo "[pump-fitness] Checking wrapper precedence..."
if ! command -v pump | grep -q "/home/builder/scripts"; then
    echo "ERROR: pump wrapper is not first in PATH"
    echo "       pump resolves to: $(command -v pump)"
    exit 1
fi
echo "  OK: wrapper is first in PATH"

# ------------------------------------------------------------
# 5. distcc internal pump disabled
# ------------------------------------------------------------
echo "[pump-fitness] Checking distcc internal pump disabled..."
if [[ "${DISTCC_PUMP:-}" == "1" ]]; then
    echo "ERROR: DISTCC_PUMP=1 detected (must be unset or 0)"
    exit 1
fi
echo "  OK: distcc internal pump disabled"

# ------------------------------------------------------------
# 6. Stale pump dirs
# ------------------------------------------------------------
echo "[pump-fitness] Cleaning stale pump dirs..."
rm -rf /tmp/distcc-pump.* || true
echo "  OK: stale pump dirs removed"

# ------------------------------------------------------------
# 7. Final PASS
# ------------------------------------------------------------
echo "[pump-fitness] Fitness check PASSED"
exit 0
