#!/bin/bash

# Destroy old VxLANs
sudo ip link del vxlan-tc 2>/dev/null
sudo ip link del vxlan-ta 2>/dev/null

# Deploy topology (ignore errors if already deployed)
sudo containerlab deploy -t ./vm-t.clab.yml || true

# Core container name
CONTAINER="clab-vm-T-lab-core-t"
PID=$(docker inspect -f '{{.State.Pid}}' $CONTAINER)

echo "Core PID: $PID"

# Create VxLANs
sudo ip link add vxlan-tc type vxlan id 1001 dev enp0s8 remote 192.168.56.20 dstport 4789
sudo ip link add vxlan-ta type vxlan id 1003 dev enp0s8 remote 192.168.56.30 dstport 4789
sudo ip link set vxlan-tc up
sudo ip link set vxlan-ta up

# Move into container
sudo ip link set vxlan-tc netns $PID
sudo ip link set vxlan-ta netns $PID

# Rename + IPs
sudo nsenter -t $PID -n ip link set vxlan-tc name eth2
sudo nsenter -t $PID -n ip link set vxlan-ta name eth3
sudo nsenter -t $PID -n ip link set eth2 up
sudo nsenter -t $PID -n ip link set eth3 up

sudo nsenter -t $PID -n ip addr add 10.0.1.0/31 dev eth2
sudo nsenter -t $PID -n ip addr add 10.0.3.1/31 dev eth3
sudo nsenter -t $PID -n ip addr add 10.255.0.1/32 dev lo