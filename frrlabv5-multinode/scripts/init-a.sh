#!/bin/bash

sudo ip link del vxlan-ac 2>/dev/null
sudo ip link del vxlan-at 2>/dev/null

sudo containerlab deploy -t ./vm-a.clab.yml || true

CONTAINER="clab-vm-a-lab-core-a"
PID=$(docker inspect -f '{{.State.Pid}}' $CONTAINER)

echo "Core PID: $PID"

# A → C
sudo ip link add vxlan-ac type vxlan id 1002 dev enp0s8 remote 192.168.56.20 dstport 4789

# A → T
sudo ip link add vxlan-at type vxlan id 1003 dev enp0s8 remote 192.168.56.40 dstport 4789

sudo ip link set vxlan-ac up
sudo ip link set vxlan-at up

sudo ip link set vxlan-ac netns $PID
sudo ip link set vxlan-at netns $PID

sudo nsenter -t $PID -n ip link set vxlan-ac name eth3
sudo nsenter -t $PID -n ip link set vxlan-at name eth2

sudo nsenter -t $PID -n ip link set eth2 up
sudo nsenter -t $PID -n ip link set eth3 up

# A → C
sudo nsenter -t $PID -n ip addr add 10.0.2.0/31 dev eth3

# A → T
sudo nsenter -t $PID -n ip addr add 10.0.3.0/31 dev eth2

sudo nsenter -t $PID -n ip addr add 10.255.0.3/32 dev lo