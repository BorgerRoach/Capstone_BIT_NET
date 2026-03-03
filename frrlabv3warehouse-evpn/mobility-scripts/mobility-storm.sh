#!/bin/bash
# mobility-storm.sh
# Aggressive EVPN mobility stress test

set -e

TORS=("tor1" "tor2" "tor3" "tor4")
HOSTS_PER_TOR=25
DELAY=1
VLAN_IF="vlan10"
UPLINK_IF="eth1"
SSH_OPTS="-o StrictHostKeyChecking=no -i /root/.ssh/id_ed25519"

create_vlan_if() {
    local TOR=$1
    ssh $SSH_OPTS root@$TOR "
        ip link show $VLAN_IF >/dev/null 2>&1 || \
        ip link add link $UPLINK_IF name $VLAN_IF type vlan id 10
        ip link set $VLAN_IF up
    "
}

create_host() {
    local TOR=$1
    local HOST=$2
    local IP="192.168.10.$3/24"

    ssh $SSH_OPTS root@$TOR "
        ip netns add $HOST 2>/dev/null || true
        ip link add veth-$HOST type veth peer name br-$HOST 2>/dev/null || true
        ip link set br-$HOST master $VLAN_IF || true
        ip link set veth-$HOST netns $HOST || true
        ip netns exec $HOST ip addr add $IP dev veth-$HOST 2>/dev/null || true
        ip netns exec $HOST ip link set lo up
        ip netns exec $HOST ip link set veth-$HOST up
        ip link set br-$HOST up
    "
}

delete_host() {
    local TOR=$1
    local HOST=$2
    ssh $SSH_OPTS root@$TOR "
        ip netns del $HOST 2>/dev/null || true
        ip link del br-$HOST 2>/dev/null || true
        ip link del veth-$HOST 2>/dev/null || true
    "
}

echo " Starting EVPN Mobility Storm..."

while true; do
    for TOR in "${TORS[@]}"; do
        create_vlan_if $TOR
    done

    for TOR in "${TORS[@]}"; do
        for i in $(seq 1 $HOSTS_PER_TOR); do
            HOST="host$i"
            for T in "${TORS[@]}"; do
                delete_host $T $HOST
            done
            create_host $TOR $HOST $((10 + i))
        done
    done

    sleep $DELAY
done