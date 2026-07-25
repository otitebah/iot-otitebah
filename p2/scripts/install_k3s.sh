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

# Detect the interface carrying the private 192.168.56.x network
# (the first interface is Vagrant's NAT; K3s must NOT advertise that one)
IFACE=$(ip -4 -o addr show | awk '/192\.168\.56\./ {print $2; exit}')
echo "Private network interface: $IFACE"

# Install K3s in server mode, pinned to the private IP
echo "Installing K3s in server mode..."
curl -sfL https://get.k3s.io | \
    INSTALL_K3S_EXEC="server --node-ip=192.168.56.110 --flannel-iface=$IFACE --write-kubeconfig-mode 644" \
    sh -

# Wait for K3s to be ready
echo "Waiting for K3s to be ready..."
sleep 10

# Set up kubectl config for easy access
mkdir -p /root/.kube
cp /etc/rancher/k3s/k3s.yaml /root/.kube/config
chmod 600 /root/.kube/config

# Also give the vagrant user a working kubectl (so `kubectl get all` needs no sudo)
mkdir -p /home/vagrant/.kube
cp /etc/rancher/k3s/k3s.yaml /home/vagrant/.kube/config
chown -R vagrant:vagrant /home/vagrant/.kube
grep -q KUBECONFIG /home/vagrant/.bashrc || \
    echo 'export KUBECONFIG=/home/vagrant/.kube/config' >> /home/vagrant/.bashrc

echo "K3s Server installation completed!"
echo "Server IP: 192.168.56.110"

# Verify K3s is running
echo "Checking K3s status..."
/usr/local/bin/kubectl get nodes

# Deploy applications from configuration files
echo "Deploying applications..."

# Vagrant's file provisioner may nest the folder as /tmp/confs/confs
CONF_DIR="/tmp/confs"
[ -d "/tmp/confs/confs" ] && CONF_DIR="/tmp/confs/confs"

if [ ! -d "$CONF_DIR" ]; then
    echo "ERROR: configuration directory not found. Apps cannot be deployed." >&2
    exit 1
fi

# Traefik is installed by K3s via a Helm job, asynchronously. The Deployment
# does not exist yet at this point, so we must wait for it to APPEAR before we
# can wait for it to become ready ("rollout status" fails instantly on a
# missing Deployment instead of waiting for it).
echo "Waiting for Traefik to appear..."
for i in $(seq 1 60); do
    if /usr/local/bin/kubectl -n kube-system get deployment traefik >/dev/null 2>&1; then
        echo "Traefik deployment found after ${i} attempt(s)."
        break
    fi
    sleep 5
done

echo "Waiting for Traefik to be ready..."
/usr/local/bin/kubectl -n kube-system rollout status deployment/traefik --timeout=300s

# ORDER MATTERS: the Ingress must be applied AFTER the Services it references.
# Applying the whole folder at once uses alphabetical order (ingress.yaml before
# services.yaml), so Traefik sees an Ingress pointing at Services that do not
# exist yet, silently creates no routers, and every request returns 404.
echo "Applying deployments..."
/usr/local/bin/kubectl apply -f "$CONF_DIR/app1-deployment.yaml" \
                             -f "$CONF_DIR/app2-deployment.yaml" \
                             -f "$CONF_DIR/app3-deployment.yaml"

echo "Applying services..."
/usr/local/bin/kubectl apply -f "$CONF_DIR/services.yaml"

echo "Waiting for application pods to become ready..."
/usr/local/bin/kubectl wait --for=condition=available --timeout=300s \
    deployment/app1 deployment/app2 deployment/app3

echo "Applying ingress..."
/usr/local/bin/kubectl apply -f "$CONF_DIR/ingress.yaml"

echo "========================================="
echo "K3s Server setup complete!"
echo "========================================="
