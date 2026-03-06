#!/bin/bash
set -e

echo "=== Detecting VM identity ==="

HOSTNAME=$(hostname)

case "$HOSTNAME" in
  *A*|*a*)
    echo "Configuring bridges for VM-A"
    BR1=br-ac
    BR2=br-at
    IF1=enp0s8   # VBoxNet1 (A-C)
    IF2=enp0s9   # VBoxNet2 (A-T)
    ;;
  *C*|*c*)
    echo "Configuring bridges for VM-C"
    BR1=br-ca
    BR2=br-ct
    IF1=enp0s8   # VBoxNet1 (C-A)
    IF2=enp0s9   # VBoxNet3 (C-T)
    ;;
  *T*|*t*)
    echo "Configuring bridges for VM-T"
    BR1=br-ta
    BR2=br-tc
    IF1=enp0s8   # VBoxNet2 (T-A)
    IF2=enp0s9   # VBoxNet3 (T-C)
    ;;
  *)
    echo "ERROR: Could not determine VM identity from hostname."
    exit 1
    ;;
esac

echo "=== Creating bridges: $BR1 and $BR2 ==="

sudo ip link add $BR1 type bridge || true
sudo ip link set $BR1 up

sudo ip link add $BR2 type bridge || true
sudo ip link set $BR2 up

echo "=== Adding NICs to bridges ==="

sudo ip link set $IF1 master $BR1
sudo ip link set $IF1 up

sudo ip link set $IF2 master $BR2
sudo ip link set $IF2 up

echo "=== Bridge setup complete ==="
ip link show type bridge