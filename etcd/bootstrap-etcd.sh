#!/bin/bash

NODE_NUM=$1
NODE_NAME="etcd-node-${NODE_NUM}"
NODE_IP="192.168.56.10${NODE_NUM}"

ETCD_VER="v3.5.12"
CLUSTER_NODES="etcd-node-1=http://192.168.56.101:2380,etcd-node-2=http://192.168.56.102:2380,etcd-node-3=http://192.168.56.103:2380"

# Update & install packages
sudo apt-get update -y
sudo apt-get install -y wget curl chrony

# Enable time sync
sudo systemctl enable --now chrony

# Install etcd
cd /tmp
wget https://github.com/etcd-io/etcd/releases/download/${ETCD_VER}/etcd-${ETCD_VER}-linux-amd64.tar.gz
tar xzvf etcd-${ETCD_VER}-linux-amd64.tar.gz
sudo mv etcd-${ETCD_VER}-linux-amd64/etcd etcd-${ETCD_VER}-linux-amd64/etcdctl /usr/local/bin/

# Create data directories
sudo mkdir -p /etc/etcd /var/lib/etcd
sudo chmod 700 /var/lib/etcd

# Create etcd service file
cat <<EOF | sudo tee /etc/systemd/system/etcd.service
[Unit]
Description=etcd
Documentation=https://github.com/coreos/etcd
After=network.target

[Service]
User=root
Type=notify
ExecStart=/usr/local/bin/etcd \\
  --name ${NODE_NAME} \\
  --initial-advertise-peer-urls http://${NODE_IP}:2380 \\
  --listen-peer-urls http://${NODE_IP}:2380 \\
  --listen-client-urls http://${NODE_IP}:2379,http://127.0.0.1:2379 \\
  --advertise-client-urls http://${NODE_IP}:2379 \\
  --initial-cluster-token etcd-cluster-1 \\
  --initial-cluster ${CLUSTER_NODES} \\
  --initial-cluster-state new \\
  --data-dir=/var/lib/etcd

Restart=always
RestartSec=5s
LimitNOFILE=40000

[Install]
WantedBy=multi-user.target
EOF

# Replace IPs in cluster string for correct binding
sudo sed -i "s/192.168.56.101/192.168.56.101/g" /etc/systemd/system/etcd.service
sudo sed -i "s/192.168.56.102/192.168.56.102/g" /etc/systemd/system/etcd.service
sudo sed -i "s/192.168.56.103/192.168.56.103/g" /etc/systemd/system/etcd.service

# Reload and start etcd
sudo systemctl daemon-reexec
sudo systemctl daemon-reload
sudo systemctl enable etcd
sudo systemctl start etcd
