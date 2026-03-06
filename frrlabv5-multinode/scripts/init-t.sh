#!/bin/bash
set -e

# Clean old tunnels
sudo ip link del vxlan-ta 2>/dev/null || true
sudo ip link del vxlan-tc 2>/dev/null || true

# Get CORE-T PID
PID=$(docker inspect -f '{{.State.Pid}}' clab-vm-t-lab-core-t)
echo "Core-T PID: $PID"

# T → A (VM-A = 192.168.56.10)
sudo ip link add vxlan-ta type vxlan id 1003 dev enp0s8 remote 192.168.56.10 dstport 4789

# T → C (VM-C = 192.168.56.20)
sudo ip link add vxlan-tc type vxlan id 1002 dev enp0s8 remote 192.168.56.20 dstport 4789

# Bring up on host before moving
sudo ip link set vxlan-ta up
sudo ip link set vxlan-tc up

# Move into CORE-T namespace
sudo ip link set vxlan-ta netns "$PID"
sudo ip link set vxlan-tc netns "$PID"

# Bring up inside CORE-T
sudo nsenter -t "$PID" -n ip link set vxlan-ta up
sudo nsenter -t "$PID" -n ip link set vxlan-tc up

# Assign IPs
# T ↔ A uses 10.0.2.1/31
sudo nsenter -t "$PID" -n ip addr add 10.0.2.1/31 dev vxlan-ta

# T ↔ C uses 10.0.3.1/31
sudo nsenter -t "$PID" -n ip addr add 10.0.3.1/31 dev vxlan-tc

# Loopback
sudo nsenter -t "$PID" -n ip addr add 10.255.0.41/32 dev lo || true

# Restart FRR
sudo nsenter -t "$PID" -n systemctl restart frr || sudo nsenter -t "$PID" -n /usr/lib/frr/frrinit.sh restart