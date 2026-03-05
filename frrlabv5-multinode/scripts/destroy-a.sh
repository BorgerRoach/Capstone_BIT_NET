#!/bin/bash

echo "Destroying VM-a lab..."

LAB_NAME="vm-a-lab"
TOPO="vm-a.clab.yml"

echo "Stopping containerlab..."
sudo containerlab destroy -t $TOPO --cleanup 2>/dev/null

echo "Removing containerlab state directory..."
sudo rm -rf /var/lib/containerlab/$LAB_NAME

echo "Removing docker containers..."
docker ps -a --format '{{.Names}}' | grep vm-a | xargs -r docker rm -f

echo "Removing docker networks..."
docker network ls --format '{{.Name}}' | grep vm-a | xargs -r docker network rm

echo "Removing VXLAN interfaces on host..."
for vx in vxlan-ct vxlan-ca vxlan-ac vxlan-at vxlan-tc vxlan-ta; do
    sudo ip link del $vx 2>/dev/null
done

echo "Cleaning inside-container VXLAN interfaces..."
# Find any running VM-A containers
for c in $(docker ps -a --format '{{.Names}}' | grep vm-a); do
    PID=$(docker inspect -f '{{.State.Pid}}' $c 2>/dev/null)
    if [ -n "$PID" ]; then
        echo "Cleaning namespace for container $c (PID $PID)..."
        sudo nsenter -t $PID -n ip link del vxlan-ac 2>/dev/null
        sudo nsenter -t $PID -n ip link del vxlan-at 2>/dev/null
        sudo nsenter -t $PID -n ip link del vxlan-ca 2>/dev/null
        sudo nsenter -t $PID -n ip link del vxlan-ct 2>/dev/null
        sudo nsenter -t $PID -n ip link del vxlan-ta 2>/dev/null
        sudo nsenter -t $PID -n ip link del vxlan-tc 2>/dev/null

        # Clean loopback assignments
        sudo nsenter -t $PID -n ip addr flush dev lo
    fi
done

echo "Removing stale bridges..."
sudo ip link show type bridge | grep br- | awk -F: '{print $2}' | xargs -r -I{} sudo ip link del {}

echo "Killing stale containerlab processes..."
sudo pkill -f containerlab

echo "VM-a lab fully cleaned."