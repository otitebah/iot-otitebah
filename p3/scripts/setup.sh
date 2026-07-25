#!/bin/bash
set -e

CLUSTER_NAME="iot"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "[1/6] Creating K3d cluster '${CLUSTER_NAME}'..."
if k3d cluster list | grep -q "^${CLUSTER_NAME} "; then
  echo "Cluster '${CLUSTER_NAME}' already exists. Skipping creation."
else
  k3d cluster create "${CLUSTER_NAME}" \
    --port "8888:30080@loadbalancer" \
    --port "8080:30081@loadbalancer"
fi

echo "[2/6] Creating namespaces..."
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace dev    --dry-run=client -o yaml | kubectl apply -f -

echo "[3/6] Installing Argo CD..."
# --server-side is required: Argo CD's applicationsets CRD exceeds the
# 256 KiB last-applied-configuration annotation limit of client-side apply.
kubectl apply --server-side -n argocd \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo "[4/6] Waiting for Argo CD server to become available (up to 10 minutes)..."
kubectl wait --for=condition=available --timeout=600s \
  deployment/argocd-server -n argocd

echo "[5/6] Exposing Argo CD UI on NodePort 30081 (mapped to host port 8080)..."
kubectl patch svc argocd-server -n argocd -p \
  '{"spec": {"type": "NodePort", "ports": [{"port": 443, "nodePort": 30081}]}}'

echo "[6/6] Applying Argo CD Application manifest..."
kubectl apply -f "${SCRIPT_DIR}/../confs/application.yaml"

echo ""
echo "Setup complete."
echo ""
echo "Argo CD admin password:"
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d
echo ""
echo ""
echo "Argo CD UI:  https://localhost:8080  (user: admin)"
echo "Application: curl http://localhost:8888/"
