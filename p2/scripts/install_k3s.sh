#!/bin/bash

set -e

echo "========================================="
echo "Installing K3s Server (Part 2)..."
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

# Install K3s in server mode
echo "Installing K3s in server mode..."
curl -sfL https://get.k3s.io | sh -

# Wait for K3s to be ready
echo "Waiting for K3s to be ready..."
sleep 10

# Set up kubectl config for easy access
mkdir -p /root/.kube
cp /etc/rancher/k3s/k3s.yaml /root/.kube/config
chmod 600 /root/.kube/config

echo "K3s Server installation completed!"
echo "Server IP: 192.168.56.110"

# Verify K3s is running
echo "Checking K3s status..."
/usr/local/bin/kubectl get nodes

# Deploy applications from configuration files
echo "Deploying applications..."
sleep 5

if [ -d "/tmp/confs" ]; then
    echo "Applying configuration files..."
    /usr/local/bin/kubectl apply -f /tmp/confs/ || echo "Configuration files will be applied manually"
fi

echo "========================================="
echo "K3s Server setup complete!"
echo "========================================="
