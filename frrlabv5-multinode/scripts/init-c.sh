#!/bin/bash

# Clean old tunnels
sudo ip link del vxlan-ca 2>/dev/null
sudo ip link del vxlan-ct 2>/dev/null

# Deploy VM-C topology
sudo containerlab deploy -t ./vm-c.clab.yml || true

# Get CORE-C PID
CONTAINER="clab-vm-c-lab-core-c"
PID=$(docker inspect -f '{{.State.Pid}}' $CONTAINER)

echo "Core-C PID: $PID"

# C → A (VM-A = 192.168.56.30)
sudo ip link add vxlan-ca type vxlan id 1002 dev enp0s8 remote 192.168.56.30 dstport 4789

# C → T (VM-T = 192.168.56.40)
sudo ip link add vxlan-ct type vxlan id 1001 dev enp0s8 remote 192.168.56.40 dstport 4789

# Bring up on host before moving
sudo ip link set vxlan-ca up
sudo ip link set vxlan-ct up

# Move into CORE-C namespace
sudo ip link set vxlan-ca netns $PID
sudo ip link set vxlan-ct netns $PID

# Bring up inside CORE-C
sudo nsenter -t $PID -n ip link set vxlan-ca up
sudo nsenter -t $PID -n ip link set vxlan-ct up

# Assign IPs directly to VxLAN interfaces
# C → A
sudo nsenter -t $PID -n ip addr add 10.0.2.1/31 dev vxlan-ca

# C → T
sudo nsenter -t $PID -n ip addr add 10.0.1.1/31 dev vxlan-ct

# Loopback (must match FRR core-c)
sudo nsenter -t $PID -n ip addr add 10.255.0.21/32 dev lo