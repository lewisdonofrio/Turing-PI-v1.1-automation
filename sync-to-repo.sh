#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="/opt/ansible-k3s-cluster"
SRC_BUILDER="/home/builder"
SRC_ANSIBLE="/home/ansible"

log() {
  printf '[sync] %s\n' "$*" >&2
}

ensure_dir() {
  local d="$1"
  if [[ ! -d "$d" ]]; then
    log "mkdir -p $d"
    mkdir -p "$d"
  fi
}

copy_if_exists() {
  local src="$1" dst="$2"
  if [[ -f "$src" ]]; then
    ensure_dir "$(dirname "$dst")"
    log "cp $src -> $dst"
    cp -p "$src" "$dst"
  fi
}

copy_glob() {
  local pattern="$1" dst_dir="$2"
  shopt -s nullglob
  local files=( $pattern )
  shopt -u nullglob
  [[ ${#files[@]} -eq 0 ]] && return 0
  ensure_dir "$dst_dir"
  for f in "${files[@]}"; do
    log "cp $f -> $dst_dir/"
    cp -p "$f" "$dst_dir/"
  done
}

log "Syncing into $REPO_ROOT"

###############################################################################
# 1) Ensure target layout (including kube-proxy structure)
###############################################################################

# kube-proxy playbooks
ensure_dir "$REPO_ROOT/playbooks/kube-proxy"

# other playbooks
ensure_dir "$REPO_ROOT/playbooks"

# roles
ensure_dir "$REPO_ROOT/roles/kube_proxy_preload/tasks"
ensure_dir "$REPO_ROOT/roles/kube_proxy_preload/files"
ensure_dir "$REPO_ROOT/roles/kube_proxy_preload/templates"
ensure_dir "$REPO_ROOT/roles/kube_proxy_validate/tasks"

# scripts
ensure_dir "$REPO_ROOT/scripts"

# docs
ensure_dir "$REPO_ROOT/docs/recovery"
ensure_dir "$REPO_ROOT/docs/doctrine"

# inventory
ensure_dir "$REPO_ROOT/inventory/group_vars"

# systemd + kube-proxy config snapshots
ensure_dir "$REPO_ROOT/systemd"
ensure_dir "$REPO_ROOT/config"

###############################################################################
# 2) Pull from /home/builder (cluster + kube-proxy + flannel + local-path)
###############################################################################

log "Syncing from $SRC_BUILDER"

# builder scripts (top-level)
copy_glob "$SRC_BUILDER/*.sh" "$REPO_ROOT/scripts"

# builder scripts subdir
copy_glob "$SRC_BUILDER/scripts/*.sh" "$REPO_ROOT/scripts"

# kube-proxy + flannel + local-path YAMLs
copy_if_exists "$SRC_BUILDER/kube-proxy.yaml" \
  "$REPO_ROOT/playbooks/kube-proxy/kube-proxy.yaml"

copy_if_exists "$SRC_BUILDER/cluster-network-kube-proxy.yaml" \
  "$REPO_ROOT/playbooks/kube-proxy/cluster-network-kube-proxy.yaml"

copy_if_exists "$SRC_BUILDER/kube-flannel-ds.yaml" \
  "$REPO_ROOT/docs/recovery/kube-flannel-ds.yaml"

copy_if_exists "$SRC_BUILDER/cluster-network-flannel.yaml" \
  "$REPO_ROOT/docs/recovery/cluster-network-flannel.yaml"

copy_if_exists "$SRC_BUILDER/local-path-config.yaml" \
  "$REPO_ROOT/config/local-path-config.yaml"

copy_if_exists "$SRC_BUILDER/local-path-provisioner.yaml" \
  "$REPO_ROOT/config/local-path-provisioner.yaml"

copy_if_exists "$SRC_BUILDER/your-kube-proxy-daemonset.yaml" \
  "$REPO_ROOT/playbooks/kube-proxy/your-kube-proxy-daemonset.yaml"

# any builder docs
copy_glob "$SRC_BUILDER/docs/*.md" "$REPO_ROOT/docs"

###############################################################################
# 3) Pull from /home/ansible (builder-side scripts only)
###############################################################################

log "Syncing from $SRC_ANSIBLE"

# ansible build scripts (top-level .sh only)
copy_glob "$SRC_ANSIBLE/*.sh" "$REPO_ROOT/scripts"

# optional: k8s-build-native helper scripts (if you want them versioned)
if [[ -d "$SRC_ANSIBLE/k8s-build-native" ]]; then
  copy_glob "$SRC_ANSIBLE/k8s-build-native/*.sh" "$REPO_ROOT/scripts"
fi

###############################################################################
# 4) Inventory + ansible config (already in repo, just ensure presence)
###############################################################################

# these are managed in-repo; we just ensure dirs exist
ensure_dir "$REPO_ROOT/inventory"
ensure_dir "$REPO_ROOT/inventory/group_vars"

###############################################################################
# 5) kube-proxy + k3s config snapshots (for rebuild doctrine)
###############################################################################

copy_if_exists "/var/lib/kube-proxy/kubeconfig" \
  "$REPO_ROOT/systemd/kubeconfig.snapshot"

copy_if_exists "/etc/systemd/system/kube-proxy.service" \
  "$REPO_ROOT/systemd/kube-proxy.service.snapshot"

copy_if_exists "/etc/systemd/system/k3s.service" \
  "$REPO_ROOT/systemd/k3s.service.snapshot"

copy_if_exists "/etc/rancher/k3s/config.yaml" \
  "$REPO_ROOT/config/k3s-config.yaml.snapshot"

###############################################################################
# 6) Placeholder kube-proxy role files (if not present)
###############################################################################

if [[ ! -f "$REPO_ROOT/playbooks/kube-proxy/preload-kube-proxy.yml" ]]; then
  cat > "$REPO_ROOT/playbooks/kube-proxy/preload-kube-proxy.yml" << 'EOF'
---
# Preload kube-proxy image onto nodes (placeholder; fill in with real tasks)
EOF
  log "created placeholder preload-kube-proxy.yml"
fi

if [[ ! -f "$REPO_ROOT/playbooks/kube-proxy/distribute-kube-proxy.yml" ]]; then
  cat > "$REPO_ROOT/playbooks/kube-proxy/distribute-kube-proxy.yml" << 'EOF'
---
# Distribute kube-proxy artifacts to nodes (placeholder; fill in with real tasks)
EOF
  log "created placeholder distribute-kube-proxy.yml"
fi

if [[ ! -f "$REPO_ROOT/playbooks/kube-proxy/validate-kube-proxy.yml" ]]; then
  cat > "$REPO_ROOT/playbooks/kube-proxy/validate-kube-proxy.yml" << 'EOF'
---
# Validate kube-proxy behavior on nodes (placeholder; fill in with real tasks)
EOF
  log "created placeholder validate-kube-proxy.yml"
fi

if [[ ! -f "$REPO_ROOT/playbooks/kube-proxy/README.md" ]]; then
  cat > "$REPO_ROOT/playbooks/kube-proxy/README.md" << 'EOF'
# kube-proxy playbooks

This directory contains playbooks for:
- preloading kube-proxy images
- distributing kube-proxy artifacts
- validating kube-proxy behavior

Fill in with real tasks as doctrine solidifies.
EOF
  log "created placeholder kube-proxy README.md"
fi

if [[ ! -f "$REPO_ROOT/roles/kube_proxy_preload/tasks/main.yml" ]]; then
  cat > "$REPO_ROOT/roles/kube_proxy_preload/tasks/main.yml" << 'EOF'
---
# kube_proxy_preload role tasks (placeholder)
EOF
  log "created placeholder kube_proxy_preload/tasks/main.yml"
fi

if [[ ! -f "$REPO_ROOT/roles/kube_proxy_preload/templates/kube-proxy.service.j2" ]]; then
  cat > "$REPO_ROOT/roles/kube_proxy_preload/templates/kube-proxy.service.j2" << 'EOF'
# systemd unit template for kube-proxy (placeholder)
EOF
  log "created placeholder kube-proxy.service.j2"
fi

if [[ ! -f "$REPO_ROOT/roles/kube_proxy_validate/tasks/main.yml" ]]; then
  cat > "$REPO_ROOT/roles/kube_proxy_validate/tasks/main.yml" << 'EOF'
---
# kube_proxy_validate role tasks (placeholder)
EOF
  log "created placeholder kube_proxy_validate/tasks/main.yml"
fi

###############################################################################
# 7) Docs placeholders for doctrine
###############################################################################

for doc in \
  "docs/recovery/2026-02-kube-proxy-rebuild.md" \
  "docs/recovery/2026-02-traefik-teardown.md" \
  "docs/recovery/2026-02-flannel-recovery.md" \
  "docs/doctrine/k3s-builtins.md" \
  "docs/doctrine/kube-proxy-architecture.md" \
  "docs/doctrine/image-preload-strategy.md"
do
  target="$REPO_ROOT/$doc"
  if [[ ! -f "$target" ]]; then
    ensure_dir "$(dirname "$target")"
    cat > "$target" << EOF
# $(basename "$doc" .md)

_TODO: capture doctrine for $(basename "$doc")_
EOF
    log "created placeholder $doc"
  fi
done

log "Sync complete."
