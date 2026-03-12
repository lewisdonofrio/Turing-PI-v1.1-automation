# =====================================================================
# FILE: /opt/ansible-k3s-cluster/bootstrap/bootstrap.sh
# PURPOSE:
#   Day-0 / Day-1 cluster bootstrap script.
#   This script is invoked by Ansible (or manually) to:
#     - Create core namespaces for cluster addons
#     - Apply cert-manager CRDs
#     - Run Helmfile to install:
#         * cert-manager
#         * ingress-nginx
#         * ArgoCD
#         * kube-prometheus-stack
#         * Loki stack
#         * Kubernetes Dashboard
#
# NOTES:
#   - ASCII-only, 2AM-safe formatting
#   - Idempotent: safe to re-run
#   - Assumes:
#       * kubectl is configured for the target cluster
#       * helm and helmfile are installed in /usr/local/bin
#       * helmfile.yaml lives in /opt/ansible-k3s-cluster/bootstrap
# =====================================================================

#!/usr/bin/env bash
set -euo pipefail

# ---------------------------------------------------------------------
# Helper: log function for consistent, 2AM-friendly output
# ---------------------------------------------------------------------
log() {
  echo "[bootstrap] $*"
}

# ---------------------------------------------------------------------
# Step 1: Create required namespaces (idempotent via apply)
# ---------------------------------------------------------------------
log "Creating core namespaces (argocd, monitoring, ingress-nginx, cert-manager, kubernetes-dashboard)..."

kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace ingress-nginx --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace cert-manager --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace kubernetes-dashboard --dry-run=client -o yaml | kubectl apply -f -

# ---------------------------------------------------------------------
# Step 2: Apply cert-manager CRDs
# These must exist before the Helm release is installed.
# ---------------------------------------------------------------------
log "Applying cert-manager CRDs..."

kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.15.0/cert-manager.crds.yaml

# ---------------------------------------------------------------------
# Step 3: Run Helmfile to sync all defined releases
# This installs all core addons in a single, declarative pass.
# ---------------------------------------------------------------------
log "Running helmfile sync to install core addons..."

cd /opt/ansible-k3s-cluster/bootstrap
helmfile sync

log "Bootstrap complete. Core addons should now be deploying."
