#!/bin/bash
set -e

CLUSTER_NAME="iot"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "[1/5] Creating K3d cluster '${CLUSTER_NAME}'..."
if k3d cluster list | grep -q "^${CLUSTER_NAME} "; then
  echo "Cluster '${CLUSTER_NAME}' already exists. Skipping creation."
else
  k3d cluster create "${CLUSTER_NAME}" \
    --port "8888:30080@loadbalancer" \
    --port "8080:30081@loadbalancer"
fi

echo "[2/5] Creating namespaces..."
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace dev    --dry-run=client -o yaml | kubectl apply -f -

echo "[3/5] Installing Argo CD..."
# --server-side is required: Argo CD's applicationsets CRD exceeds the
# 256 KiB last-applied-configuration annotation limit of client-side apply.
kubectl apply --server-side -n argocd \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo "[4/5] Waiting for Argo CD server to become available (up to 10 minutes)..."
kubectl wait --for=condition=available --timeout=600s \
  deployment/argocd-server -n argocd

echo "[5/5] Applying Argo CD Application manifest..."
kubectl apply -f "${SCRIPT_DIR}/../confs/application.yaml"

echo ""
echo "Setup complete."
echo ""
echo "Argo CD admin password:"
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d
echo ""
echo ""
echo "To open the Argo CD UI:"
echo "  kubectl port-forward -n argocd svc/argocd-server 8080:443"
echo "  Then browse to https://localhost:8080  (user: admin)"
echo ""
echo "To test the deployed application:"
echo "  kubectl port-forward -n dev svc/wil-playground 8888:8888"
echo "  curl http://localhost:8888/"
