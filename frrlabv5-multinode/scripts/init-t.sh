#!/bin/bash

sudo ip link del vxlan-tc 2>/dev/null
sudo ip link del vxlan-ta 2>/dev/null

sudo containerlab deploy -t ./vm-t.clab.yml || true

CONTAINER="clab-vm-t-lab-core-t"
PID=$(docker inspect -f '{{.State.Pid}}' $CONTAINER)

echo "Core PID: $PID"

# T → C (VM-C = 192.168.56.20)
sudo ip link add vxlan-tc type vxlan id 1001 dev enp0s8 remote 192.168.56.20 dstport 4789

# T → A (VM-A = 192.168.56.30)
sudo ip link add vxlan-ta type vxlan id 1003 dev enp0s8 remote 192.168.56.30 dstport 4789

sudo ip link set vxlan-tc up
sudo ip link set vxlan-ta up

sudo ip link set vxlan-tc netns $PID
sudo ip link set vxlan-ta netns $PID

sudo nsenter -t $PID -n ip link set vxlan-tc up
sudo nsenter -t $PID -n ip link set vxlan-ta up

# T → C
sudo nsenter -t $PID -n ip addr add 10.0.1.0/31 dev vxlan-tc

# T → A
sudo nsenter -t $PID -n ip addr add 10.0.3.1/31 dev vxlan-ta

sudo nsenter -t $PID -n ip addr add 10.255.0.1/32 dev lo