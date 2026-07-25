#!/bin/bash

set -e

K3S_SHARED_TOKEN="iot-cluster-token-werrahma"

echo "========================================="
echo "Installing K3s Agent (Worker)..."
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

# Wait for server to be ready
echo "Waiting for K3s server to be ready..."
sleep 10

echo "Using shared K3S token for cluster join."

# Detect the interface carrying the private 192.168.56.x network
# (the first interface is Vagrant's NAT; K3s must NOT advertise that one)
IFACE=$(ip -4 -o addr show | awk '/192\.168\.56\./ {print $2; exit}')
echo "Private network interface: $IFACE"

# Install K3s in agent mode, pinned to the private IP
echo "Installing K3s in agent mode..."
curl -sfL https://get.k3s.io | \
    K3S_URL=https://192.168.56.110:6443 \
    K3S_TOKEN="$K3S_SHARED_TOKEN" \
    INSTALL_K3S_EXEC="agent --node-ip=192.168.56.111 --flannel-iface=$IFACE" \
    sh -

# Wait for agent to register
echo "Waiting for agent to register with server..."
sleep 10

echo "K3s Agent installation completed!"
echo "Agent IP: 192.168.56.111"

echo "========================================="
echo "K3s Agent setup complete!"
echo "========================================="
