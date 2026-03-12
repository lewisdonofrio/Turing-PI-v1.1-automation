#!/usr/bin/env bash
set -euo pipefail

K8S_VERSION="v1.34.3"
BUILD_ROOT="${HOME}/k8s-build-native"
SRC_DIR="${BUILD_ROOT}/kubernetes"
ARTIFACT_ROOT="${BUILD_ROOT}/artifacts"

LOG_FILE="${BUILD_ROOT}/build-${K8S_VERSION}-$(date +%Y%m%d-%H%M%S).log"

COMPONENTS=(
  "cmd/kubelet:kubelet"
  "cmd/kube-proxy:kube-proxy"
  "cmd/kubeadm:kubeadm"
  "cmd/kubectl:kubectl"
  "cmd/kube-apiserver:kube-apiserver"
  "cmd/kube-controller-manager:kube-controller-manager"
  "cmd/kube-scheduler:kube-scheduler"
)

echo "Starting ARMv7 build for Kubernetes ${K8S_VERSION}" | tee "${LOG_FILE}"

echo "[1/6] Preparing directories..." | tee -a "${LOG_FILE}"
mkdir -p "${BUILD_ROOT}" "${ARTIFACT_ROOT}"

echo "  BUILD_ROOT:    ${BUILD_ROOT}" | tee -a "${LOG_FILE}"
echo "  SRC_DIR:       ${SRC_DIR}" | tee -a "${LOG_FILE}"
echo "  ARTIFACT_ROOT: ${ARTIFACT_ROOT}" | tee -a "${LOG_FILE}"
echo "  LOG_FILE:      ${LOG_FILE}" | tee -a "${LOG_FILE}"

echo "[2/6] Validating tools..." | tee -a "${LOG_FILE}"
command -v go   >/dev/null || { echo "ERROR: Go not installed"   | tee -a "${LOG_FILE}"; exit 1; }
command -v git  >/dev/null || { echo "ERROR: git not installed"  | tee -a "${LOG_FILE}"; exit 1; }
command -v make >/dev/null || { echo "ERROR: make not installed" | tee -a "${LOG_FILE}"; exit 1; }

echo "  Go:   $(go version)"        | tee -a "${LOG_FILE}"
echo "  Git:  $(git --version)"     | tee -a "${LOG_FILE}"
echo "  Make: $(make -v | head -n1)"| tee -a "${LOG_FILE}"

echo "[3/6] Fetching Kubernetes source..." | tee -a "${LOG_FILE}"
if [ ! -d "${SRC_DIR}" ]; then
  git clone https://github.com/kubernetes/kubernetes.git "${SRC_DIR}" 2>&1 | tee -a "${LOG_FILE}"
fi

cd "${SRC_DIR}"
git fetch --all --tags 2>&1 | tee -a "${LOG_FILE}"
git checkout "${K8S_VERSION}" 2>&1 | tee -a "${LOG_FILE}"

echo "[4/6] Cleaning build tree + Go caches..." | tee -a "${LOG_FILE}"
make clean >/dev/null 2>&1 || true
go clean -cache -modcache 2>&1 | tee -a "${LOG_FILE}"

echo "[5/6] Configuring Go environment for ARMv7..." | tee -a "${LOG_FILE}"

export GOOS=linux
export GOARCH=arm
export GOARM=7
export CGO_ENABLED=0
export GOFLAGS="-tags=nocgo"

export GOCACHE="/mnt/storage/go-build/cache"
export GOTMPDIR="/mnt/storage/go-build/tmp"
mkdir -p "$GOCACHE" "$GOTMPDIR"

echo "  GOOS=${GOOS}"        | tee -a "${LOG_FILE}"
echo "  GOARCH=${GOARCH}"    | tee -a "${LOG_FILE}"
echo "  GOARM=${GOARM}"      | tee -a "${LOG_FILE}"
echo "  CGO_ENABLED=${CGO_ENABLED}" | tee -a "${LOG_FILE}"
echo "  GOCACHE=${GOCACHE}"  | tee -a "${LOG_FILE}"
echo "  GOTMPDIR=${GOTMPDIR}"| tee -a "${LOG_FILE}"

echo "[6/6] Building components..." | tee -a "${LOG_FILE}"

for entry in "${COMPONENTS[@]}"; do
  IFS=":" read -r what name <<< "${entry}"

  ARTIFACT_DIR="${ARTIFACT_ROOT}/${name}"
  mkdir -p "${ARTIFACT_DIR}"

  echo "----" | tee -a "${LOG_FILE}"
  echo "Building ${name} (${what})..." | tee -a "${LOG_FILE}"

  make WHAT="${what}" 2>&1 | tee -a "${LOG_FILE}"

  OUTPUT_BIN="_output/bin/${name}"
  TARGET_BIN="${ARTIFACT_DIR}/${name}-${K8S_VERSION}-armv7"

  if [ ! -f "${OUTPUT_BIN}" ]; then
    echo "ERROR: Expected output binary not found: ${OUTPUT_BIN}" | tee -a "${LOG_FILE}"
    exit 1
  fi

  cp "${OUTPUT_BIN}" "${TARGET_BIN}"

  echo "Verifying ${TARGET_BIN}..." | tee -a "${LOG_FILE}"
  file "${TARGET_BIN}" | tee -a "${LOG_FILE}"
done

echo "All components built successfully for ARMv7." | tee -a "${LOG_FILE}"
echo "Artifacts are under: ${ARTIFACT_ROOT}" | tee -a "${LOG_FILE}"
