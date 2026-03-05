#!/bin/bash

echo "Destroying VM-a lab..."

LAB_NAME="vm-a-lab"
TOPO="vm-a.clab.yml"

echo "Stopping containerlab..."
sudo containerlab destroy -t $TOPO --cleanup 2>/dev/null

echo "Removing containerlab state directory..."
sudo rm -rf /var/lib/containerlab/$LAB_NAME

echo "Removing docker containers..."
docker ps -a --format '{{.Names}}' | grep vm-c | xargs -r docker rm -f

echo "Removing docker networks..."
docker network ls --format '{{.Name}}' | grep vm-c | xargs -r docker network rm

echo "Removing VXLAN interfaces..."
for vx in vxlan-ct vxlan-ca vxlan-ac vxlan-at vxlan-tc vxlan-ta; do
    sudo ip link del $vx 2>/dev/null
done

echo "Removing stale bridges..."
sudo ip link show type bridge | grep br- | awk -F: '{print $2}' | xargs -r -I{} sudo ip link del {}

echo "Killing stale containerlab processes..."
sudo pkill -f containerlab

echo "VM-C lab fully cleaned."