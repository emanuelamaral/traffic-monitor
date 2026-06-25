#!/usr/bin/env bash
set -euo pipefail

MICROK8S_CHANNEL="1.32/stable"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

log "Starting MicroK8s destructive reinstall..."

if command -v microk8s >/dev/null 2>&1; then
  log "Stopping MicroK8s..."
  microk8s stop || true
fi

log "Removing MicroK8s snap..."
snap remove microk8s --purge || true

log "Cleaning remaining MicroK8s directories..."
rm -rf /var/snap/microk8s || true
rm -rf /snap/microk8s || true

log "Cleaning CNI directories..."
rm -rf /var/lib/cni || true
rm -rf /etc/cni/net.d || true

log "Removing old department bridges if present..."
ip link delete br-hr 2>/dev/null || true
ip link delete br-fi 2>/dev/null || true
ip link delete br-dev 2>/dev/null || true

log "Cleaning basic iptables rules..."
iptables -F || true
iptables -t nat -F || true
iptables -t mangle -F || true

log "Installing MicroK8s ${MICROK8S_CHANNEL}..."
snap install microk8s --classic --channel="${MICROK8S_CHANNEL}"

log "Waiting for MicroK8s readiness..."
microk8s status --wait-ready

log "Enabling required addons..."
microk8s enable dns
microk8s enable hostpath-storage
microk8s enable helm3
microk8s enable community

log "Enabling Multus..."
microk8s enable multus

log "Waiting for MicroK8s after addons..."
microk8s status --wait-ready

log "Creating kubectl symlink..."
ln -sf /snap/bin/microk8s.kubectl /usr/local/bin/kubectl || true

log "Cluster status:"
microk8s kubectl get nodes -o wide || true

log "Checking Multus pods:"
microk8s kubectl get pods -n kube-system | grep -i multus || true

# log "Setting common user and kubectl alias"
# sudo usermod -aG microk8s $USER
# sudo chown -R $USER ~/.kube 2>/dev/null || true
# newgrp microk8s
# sudo snap alias microk8s.kubectl kubectl

log "MicroK8s reinstall completed."
