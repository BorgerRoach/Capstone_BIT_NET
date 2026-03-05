#!/bin/bash

# Clean old tunnels
sudo ip link del vxlan-ac 2>/dev/null
sudo ip link del vxlan-at 2>/dev/null

# Deploy VM-A topology
sudo containerlab deploy -t ./vm-a.clab.yml || true

# Get CORE-A PID
CONTAINER="clab-vm-a-lab-core-a"
PID=$(docker inspect -f '{{.State.Pid}}' $CONTAINER)

echo "Core-A PID: $PID"

# A → C (VM-C = 192.168.56.20)
sudo ip link add vxlan-ac type vxlan id 1002 dev enp0s8 remote 192.168.56.20 dstport 4789

# A → T (VM-T = 192.168.56.40)
sudo ip link add vxlan-at type vxlan id 1003 dev enp0s8 remote 192.168.56.40 dstport 4789

# Bring up on host before moving
sudo ip link set vxlan-ac up
sudo ip link set vxlan-at up

# Move into CORE-A namespace
sudo ip link set vxlan-ac netns $PID
sudo ip link set vxlan-at netns $PID

# Bring up inside CORE-A
sudo nsenter -t $PID -n ip link set vxlan-ac up
sudo nsenter -t $PID -n ip link set vxlan-at up

# Assign IPs directly to VxLAN interfaces
# A → C
sudo nsenter -t $PID -n ip addr add 10.0.2.0/31 dev vxlan-ac

# A → T
sudo nsenter -t $PID -n ip addr add 10.0.3.0/31 dev vxlan-at

# Loopback (must match FRR core-a)
sudo nsenter -t $PID -n ip addr add 10.255.0.1/32 dev lo