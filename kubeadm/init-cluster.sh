#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== Initializing Kubernetes Cluster ==="

# Initialize the cluster
kubeadm init --config "${SCRIPT_DIR}/kubeadm-config.yaml" --upload-certs

# Set up kubeconfig for current user
echo "Setting up kubeconfig..."
mkdir -p $HOME/.kube
cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
chown $(id -u):$(id -g) $HOME/.kube/config

# Wait for API server
echo "Waiting for API server..."
until kubectl get nodes &>/dev/null; do
  echo "Waiting for cluster to be ready..."
  sleep 5
done

# Install Flannel CNI (or use your preferred CNI)
echo "Installing Flannel CNI..."
kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml

# Verify DRA feature gate is enabled
echo ""
echo "=== Verifying DRA Configuration ==="
echo "Checking API server feature gates..."
kubectl get pods -n kube-system -l component=kube-apiserver -o yaml | grep -A5 "feature-gates" || echo "Feature gates configured via kubeadm config"

echo ""
echo "Checking if resource.k8s.io/v1beta1 API is enabled..."
kubectl api-resources | grep -i resourceslice && echo "✓ DRA API enabled" || echo "✗ DRA API not found"

echo ""
echo "=== Cluster Initialized Successfully ==="
echo ""
echo "To join worker nodes, run on each worker:"
echo ""
kubeadm token create --print-join-command
echo ""
echo "For GPU nodes, also install:"
echo "  - NVIDIA drivers"
echo "  - NVIDIA Container Toolkit"
echo "  - k8s-dra-driver-gpu"
