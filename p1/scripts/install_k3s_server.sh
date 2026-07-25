#!/bin/bash

set -e

K3S_SHARED_TOKEN="iot-cluster-token-werrahma"

echo "========================================="
echo "Installing K3s Server (Controller)..."
echo "========================================="

# Update system packages
apt-get update
apt-get upgrade -y

# Install required packages
apt-get install -y \
    curl \
    wget \
    vim \
    git \
    net-tools \
    htop

# Detect the interface carrying the private 192.168.56.x network
# (the first interface is Vagrant's NAT; K3s must NOT advertise that one)
IFACE=$(ip -4 -o addr show | awk '/192\.168\.56\./ {print $2; exit}')
echo "Private network interface: $IFACE"

# Install K3s in server mode (controller), pinned to the private IP
echo "Installing K3s in server mode..."
curl -sfL https://get.k3s.io | \
    K3S_TOKEN="$K3S_SHARED_TOKEN" \
    INSTALL_K3S_EXEC="server --node-ip=192.168.56.110 --flannel-iface=$IFACE" \
    sh -

# Wait for K3s to be ready
echo "Waiting for K3s to be ready..."
sleep 10

# Set up kubectl config for easy access
mkdir -p /root/.kube
cp /etc/rancher/k3s/k3s.yaml /root/.kube/config
chmod 600 /root/.kube/config

# Token configured for worker node join
echo "K3s Server installation completed!"
echo "Node Token (for agents): $K3S_SHARED_TOKEN"
echo "Server IP: 192.168.56.110"

# Verify K3s is running
echo "Checking K3s status..."
/usr/local/bin/kubectl get nodes || echo "Waiting for K3s to fully initialize..."

echo "========================================="
echo "K3s Server setup complete!"
echo "========================================="
