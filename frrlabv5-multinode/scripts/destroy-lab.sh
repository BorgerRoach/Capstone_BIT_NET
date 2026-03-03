#!/bin/bash

echo "Destroying lab on this VM..."

# Detect VM role based on host-only IP
HOST_IP=$(ip -4 addr show enp0s8 | grep -oP '(?<=inet\s)\d+(\.\d+){3}')

if [[ "$HOST_IP" == "192.168.56.40" ]]; then
    VM="t"
elif [[ "$HOST_IP" == "192.168.56.20" ]]; then
    VM="c"
elif [[ "$HOST_IP" == "192.168.56.30" ]]; then
    VM="a"
else
    echo "Unknown VM IP. Exiting."
    exit 1
fi

echo "Detected VM-$VM"

# Destroy containerlab topology
echo "Destroying containerlab topology..."
sudo containerlab destroy -t ./vm-$VM.clab.yml --cleanup

# Clean up any leftover VxLAN interfaces
echo "Cleaning up VxLAN interfaces..."
sudo ip link del vxlan-tc 2>/dev/null
sudo ip link del vxlan-ta 2>/dev/null
sudo ip link del vxlan-ct 2>/dev/null
sudo ip link del vxlan-ca 2>/dev/null
sudo ip link del vxlan-ac 2>/dev/null
sudo ip link del vxlan-at 2>/dev/null

# Clean up any stale namespaces (rare but safe)
echo "Cleaning stale namespaces..."
for ns in $(ip netns list | awk '{print $1}'); do
    sudo ip netns delete "$ns" 2>/dev/null
done

echo "Lab teardown complete on VM-$VM."