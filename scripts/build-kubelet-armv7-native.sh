#!/usr/bin/env bash
set -euo pipefail

# -----------------------------------------------------------------------------
#  Kubernetes kubelet ARMv7 Native Build Script (runs on ARMv7 builder node)
# -----------------------------------------------------------------------------


K8S_VERSION="v1.34.3"
BUILD_ROOT="${HOME}/k8s-build-native"
SRC_DIR="${BUILD_ROOT}/kubernetes"
ARTIFACT_DIR="${BUILD_ROOT}/artifacts/kubelet"

echo "[1/5] Preparing directories..."
mkdir -p "${BUILD_ROOT}" "${ARTIFACT_DIR}"

echo "  BUILD_ROOT:   ${BUILD_ROOT}"
echo "  ARTIFACT_DIR: ${ARTIFACT_DIR}"

# -----------------------------------------------------------------------------
# 2. Validate tools
# -----------------------------------------------------------------------------
echo "[2/5] Validating tools..."

command -v go >/dev/null || { echo "ERROR: Go not installed"; exit 1; }
command -v git >/dev/null || { echo "ERROR: git not installed"; exit 1; }
command -v make >/dev/null || { echo "ERROR: make not installed"; exit 1; }

echo "  Go:   $(go version)"
echo "  Git:  $(git --version)"
echo "  Make: $(make -v | head -n 1)"

# -----------------------------------------------------------------------------
# 3. Fetch Kubernetes source
# -----------------------------------------------------------------------------
echo "[3/5] Fetching Kubernetes source..."

if [ ! -d "${SRC_DIR}" ]; then
    git clone https://github.com/kubernetes/kubernetes.git "${SRC_DIR}"
fi

cd "${SRC_DIR}"
git fetch --all --tags
git checkout "${K8S_VERSION}"

# -----------------------------------------------------------------------------
# 4. Clean build tree
# -----------------------------------------------------------------------------
echo "[4/5] Cleaning build tree..."
make clean >/dev/null 2>&1 || true
go clean -cache -modcache

# -----------------------------------------------------------------------------
# 5. Build kubelet (pure Go, no CGO)
# -----------------------------------------------------------------------------

export GOOS=linux
export GOARCH=arm
export GOARM=7
export CGO_ENABLED=0
export GOFLAGS="-tags=nocgo"

# Redirect Go build cache + temp to real disk
export GOCACHE="/mnt/storage/go-build/cache"
export GOTMPDIR="/mnt/storage/go-build/tmp"
mkdir -p "$GOCACHE" "$GOTMPDIR"
echo "[5/5] Building kubelet for ARMv7 (native)..."

make WHAT=cmd/kubelet

# Copy artifact
OUTPUT_BIN="_output/bin/kubelet"
TARGET_BIN="${ARTIFACT_DIR}/kubelet-${K8S_VERSION}-armv7"

cp "${OUTPUT_BIN}" "${TARGET_BIN}"

echo "Verifying binary format..."
file "${TARGET_BIN}"

echo "Build complete."
echo "Binary: ${TARGET_BIN}"
