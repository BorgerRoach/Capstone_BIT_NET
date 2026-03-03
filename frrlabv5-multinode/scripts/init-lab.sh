#!/bin/bash

# Detect which VM this is based on its host-only IP
HOST_IP=$(ip -4 addr show enp0s8 | grep -oP '(?<=inet\s)\d+(\.\d+){3}')

echo "Detected host IP: $HOST_IP"

# Map VM role
if [[ "$HOST_IP" == "192.168.56.40" ]]; then
    VM="T"
elif [[ "$HOST_IP" == "192.168.56.20" ]]; then
    VM="C"
elif [[ "$HOST_IP" == "192.168.56.30" ]]; then
    VM="A"
else
    echo "Unknown VM IP. Exiting."
    exit 1
fi

echo "Running initialization for VM-$VM"

# Deploy containerlab topology
echo "Deploying containerlab topology..."
sudo containerlab deploy -t vm-$VM.clab.yml

# Determine core container name
CORE="core-$(echo $VM | tr '[:upper:]' '[:lower:]')"
CONTAINER="clab-vm-$VM-lab-$CORE"

echo "Waiting for container $CONTAINER to start..."
sleep 3

PID=$(docker inspect -f '{{.State.Pid}}' $CONTAINER)

echo "Container PID: $PID"

# Clean up any leftover VxLANs
sudo ip link del vxlan-tc 2>/dev/null
sudo ip link del vxlan-ta 2>/dev/null
sudo ip link del vxlan-ct 2>/dev/null
sudo ip link del vxlan-ca 2>/dev/null
sudo ip link del vxlan-ac 2>/dev/null
sudo ip link del vxlan-at 2>/dev/null

# VM-specific wiring
case $VM in

"T")
    echo "Configuring VxLANs for VM-T"

    sudo ip link add vxlan-tc type vxlan id 1001 dev enp0s8 remote 192.168.56.20 dstport 4789
    sudo ip link add vxlan-ta type vxlan id 1003 dev enp0s8 remote 192.168.56.30 dstport 4789
    sudo ip link set vxlan-tc up
    sudo ip link set vxlan-ta up

    sudo ip link set vxlan-tc netns $PID
    sudo ip link set vxlan-ta netns $PID

    sudo nsenter -t $PID -n ip link set vxlan-tc name eth2
    sudo nsenter -t $PID -n ip link set vxlan-ta name eth3
    sudo nsenter -t $PID -n ip link set eth2 up
    sudo nsenter -t $PID -n ip link set eth3 up

    sudo nsenter -t $PID -n ip addr add 10.0.1.0/31 dev eth2
    sudo nsenter -t $PID -n ip addr add 10.0.3.1/31 dev eth3
    sudo nsenter -t $PID -n ip addr add 10.255.0.1/32 dev lo
;;

"C")
    echo "Configuring VxLANs for VM-C"

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
;;

"A")
    echo "Configuring VxLANs for VM-A"

    sudo ip link add vxlan-ac type vxlan id 1002 dev enp0s8 remote 192.168.56.20 dstport 4789
    sudo ip link add vxlan-at type vxlan id 1003 dev enp0s8 remote 192.168.56.40 dstport 4789
    sudo ip link set vxlan-ac up
    sudo ip link set vxlan-at up

    sudo ip link set vxlan-ac netns $PID
    sudo ip link set vxlan-at netns $PID

    sudo nsenter -t $PID -n ip link set vxlan-ac name eth3
    sudo nsenter -t $PID -n ip link set vxlan-at name eth2
    sudo nsenter -t $PID -n ip link set eth2 up
    sudo nsenter -t $PID -n ip link set eth3 up

    sudo nsenter -t $PID -n ip addr add 10.0.2.1/31 dev eth3
    sudo nsenter -t $PID -n ip addr add 10.0.3.0/31 dev eth2
    sudo nsenter -t $PID -n ip addr add 10.255.0.3/32 dev lo
;;

esac

echo "Initialization complete for VM-$VM"