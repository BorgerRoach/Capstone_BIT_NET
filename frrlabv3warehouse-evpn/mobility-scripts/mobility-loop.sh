#!/bin/bash
# mobility-loop.sh
# Clean sequential host mobility across 4 ToRs

set -e
set -x

# =========================
# Configuration
# =========================
HOST_IP="192.168.10.11/24"
HOST_NS="host1"
VLAN_IF="vlan10"
DELAY=5
DETACH_DELAY=1

TORS=("tor1" "tor2" "tor3" "tor4")
UPLINK_IF="eth1"

SSH_OPTS="-o StrictHostKeyChecking=no -i /root/.ssh/id_ed25519"

# =========================
# Functions
# =========================

create_vlan_if() {
    local TOR=$1
    ssh $SSH_OPTS root@$TOR "
        ip link show $VLAN_IF >/dev/null 2>&1 || \
        ip link add link $UPLINK_IF name $VLAN_IF type vlan id 10
        ip link set $VLAN_IF up
    "
}

delete_host_ns() {
    local TOR=$1
    ssh $SSH_OPTS root@$TOR "
        ip netns del $HOST_NS 2>/dev/null || true
        ip link del br0 2>/dev/null || true
        ip link del veth0 2>/dev/null || true
    "
}

create_host_ns() {
    local TOR=$1
    ssh $SSH_OPTS root@$TOR "
        ip netns add $HOST_NS

        ip link add veth0 type veth peer name br0
        ip link set br0 master $VLAN_IF

        ip link set veth0 netns $HOST_NS

        ip netns exec $HOST_NS ip addr flush dev veth0
        ip netns exec $HOST_NS ip addr add $HOST_IP dev veth0

        ip netns exec $HOST_NS ip link set lo up
        ip netns exec $HOST_NS ip link set veth0 up

        ip link set br0 up
    "
}

# =========================
# Main Loop
# =========================

echo "Starting clean host mobility test..."

CURRENT_TOR=""

while true; do
    for TOR in "${TORS[@]}"; do
        echo "=============================="
        echo "Moving host to $TOR"
        echo "=============================="

        # 1️⃣ Detach from previous ToR
        if [ -n "$CURRENT_TOR" ]; then
            echo "Detaching from $CURRENT_TOR"
            delete_host_ns $CURRENT_TOR
            sleep $DETACH_DELAY
        fi

        # 2️⃣ Ensure VLAN exists
        create_vlan_if $TOR

        # 3️⃣ Attach to new ToR
        create_host_ns $TOR

        CURRENT_TOR=$TOR

        sleep $DELAY
    done
done