#!/bin/bash

sudo ip link del vxlan-ct 2>/dev/null
sudo ip link del vxlan-ca 2>/dev/null

sudo containerlab deploy -t ./vm-c.clab.yml || true

CONTAINER="clab-vm-C-lab-core-c"
PID=$(docker inspect -f '{{.State.Pid}}' $CONTAINER)

echo "Core PID: $PID"

sudo ip link add vxlan-ct type vxlan id 1001 dev enp0s8 remote 192.168.56.40 dstport 4789
sudo ip link add vxlan-ca type vxlan id 1002 dev enp0s8 remote 192.168.56.30 dstport 4789
sudo ip link set vxlan-ct up
sudo ip link set vxlan-ca up

sudo ip link set vxlan-ct netns $PID
sudo ip link set vxlan-ca netns $PID

sudo nsenter -t $PID -n ip link set vxlan-ct name eth2
sudo nsenter -t $PID -n ip link set vxlan-ca name eth3
sudo nsenter -t $PID -n ip link set eth2 up
sudo nsenter -t $PID -n ip link set eth3 up

sudo nsenter -t $PID -n ip addr add 10.0.1.1/31 dev eth2
sudo nsenter -t $PID -n ip addr add 10.0.2.0/31 dev eth3
sudo nsenter -t $PID -n ip addr add 10.255.0.2/32 dev lo