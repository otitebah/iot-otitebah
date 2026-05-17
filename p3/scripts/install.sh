#!/bin/bash
set -e

echo "[1/5] Updating package index..."
sudo apt-get update
sudo apt-get install -y curl ca-certificates

echo "[2/5] Installing Docker..."
if ! command -v docker &>/dev/null; then
  curl -fsSL https://get.docker.com | sh
  sudo usermod -aG docker "$USER"
  echo "Docker installed. You MUST log out and back in for the docker group to apply."
else
  echo "Docker already installed."
fi

echo "[3/5] Installing kubectl..."
if ! command -v kubectl &>/dev/null; then
  KUBECTL_VERSION=$(curl -Ls https://dl.k8s.io/release/stable.txt)
  curl -LO "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl"
  sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
  rm kubectl
else
  echo "kubectl already installed."
fi

echo "[4/5] Installing K3d..."
if ! command -v k3d &>/dev/null; then
  curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash
else
  echo "K3d already installed."
fi

echo "[5/5] Installing Argo CD CLI..."
if ! command -v argocd &>/dev/null; then
  curl -sSL -o argocd \
    https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
  sudo install -m 555 argocd /usr/local/bin/argocd
  rm argocd
else
  echo "Argo CD CLI already installed."
fi

echo ""
echo "All tools installed."
echo "If Docker was just installed, log out and back in before running setup.sh."
