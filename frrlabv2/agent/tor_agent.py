#!/usr/bin/env python3
import json
import os
import socket
import time
from pyroute2 import IPRoute

print("AGENT STARTED — TOP OF SCRIPT")


TOR_NAME = socket.gethostname()
CONTROLLER_IP = os.getenv("CONTROLLER_IP", "172.20.20.1")
CONTROLLER_PORT = int(os.getenv("CONTROLLER_PORT", "5000"))
BRIDGE_IF = os.getenv("BRIDGE_IF", "br10")
POLL_INTERVAL = 2.0

def send_event(payload):
    payload["tor"] = TOR_NAME
    payload["timestamp"] = time.time()
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        s.connect((CONTROLLER_IP, CONTROLLER_PORT))
        s.send(json.dumps(payload).encode())
        s.close()
        print(f"[agent:{TOR_NAME}] sent {payload}")
    except Exception as e:
        print(f"[agent:{TOR_NAME}] send failed: {e}")

def get_bridge_macs(ip):
    macs = set()
    try:
        fdb_entries = ip.fdb("dump")
    except Exception as e:
        print(f"FDB read error: {e}")
        return macs

    for entry in fdb_entries:
        attrs = dict(entry.get("attrs", []))
        mac = attrs.get("NDA_LLADDR")
        if mac:
            macs.add(mac.lower())
    return macs


def get_ip_for_mac(ip, mac):
    for neigh in ip.get_neighbours():
        attrs = dict(neigh.get("attrs", []))
        if attrs.get("NDA_LLADDR", "").lower() == mac:
            return attrs.get("NDA_DST")
    return None

def monitor_hosts():
    ip = IPRoute()
    known = set()

    while True:
        current = get_bridge_macs(ip)

        # New hosts
        for mac in current - known:
            ipaddr = get_ip_for_mac(ip, mac)
            send_event({
                "event": "host-up",
                "mac": mac,
                "ip": ipaddr
            })

        # Removed hosts
        for mac in known - current:
            send_event({
                "event": "host-down",
                "mac": mac
            })

        known = current
        time.sleep(POLL_INTERVAL)

if __name__ == "__main__":
    print(f"[agent:{TOR_NAME}] starting, watching {BRIDGE_IF}")
    monitor_hosts()
