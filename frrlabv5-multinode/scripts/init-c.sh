#!/bin/bash
set -e

# Clean old tunnels
sudo ip link del vxlan-ca 2>/dev/null || true
sudo ip link del vxlan-ct 2>/dev/null || true

# Get CORE-C PID
PID=$(docker inspect -f '{{.State.Pid}}' clab-vm-c-lab-core-c)
echo "Core-C PID: $PID"

# C → A (VM-A = 192.168.56.10)
sudo ip link add vxlan-ca type vxlan id 1002 dev enp0s8 remote 192.168.56.10 dstport 4789

# C → T (VM-T = 192.168.56.40)
sudo ip link add vxlan-ct type vxlan id 1003 dev enp0s8 remote 192.168.56.40 dstport 4789

# Bring up on host before moving
sudo ip link set vxlan-ca up
sudo ip link set vxlan-ct up

# Move into CORE-C namespace
sudo ip link set vxlan-ca netns "$PID"
sudo ip link set vxlan-ct netns "$PID"

# Bring up inside CORE-C
sudo nsenter -t "$PID" -n ip link set vxlan-ca up
sudo nsenter -t "$PID" -n ip link set vxlan-ct up

# Assign IPs
# C ↔ A uses 10.0.1.1/31
sudo nsenter -t "$PID" -n ip addr add 10.0.1.1/31 dev vxlan-ca

# C ↔ T uses 10.0.3.0/31
sudo nsenter -t "$PID" -n ip addr add 10.0.3.0/31 dev vxlan-ct

# Loopback
sudo nsenter -t "$PID" -n ip addr add 10.255.0.21/32 dev lo || true

# Restart FRR
sudo nsenter -t "$PID" -n systemctl restart frr || sudo nsenter -t "$PID" -n /usr/lib/frr/frrinit.sh restart