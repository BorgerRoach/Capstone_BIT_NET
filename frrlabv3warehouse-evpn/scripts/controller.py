from http.server import BaseHTTPRequestHandler, HTTPServer
import json
from datetime import datetime
import time
from collections import deque

HOST_LOCATIONS = {}

# =========================
# ADDED: Instability Detection
# =========================
EVENT_WINDOW = deque()
HOST_EVENT_HISTORY = {}

EVENT_THRESHOLD = 40     # total events
TIME_WINDOW = 3          # seconds
FLAP_THRESHOLD = 6       # same host moves in window


def check_network_health():
    now = time.time()

    # Remove old global events
    while EVENT_WINDOW and now - EVENT_WINDOW[0] > TIME_WINDOW:
        EVENT_WINDOW.popleft()

    # 🚨 Global churn detection
    if len(EVENT_WINDOW) > EVENT_THRESHOLD:
        print("\n########################################")
        print("🚨🚨🚨 NETWORK CRASH DETECTED 🚨🚨🚨")
        print(f"High mobility churn: {len(EVENT_WINDOW)} events in {TIME_WINDOW} seconds")
        print("Control plane instability likely.")
        print("########################################\n")

    # 🚨 Host flap detection
    for host, timestamps in HOST_EVENT_HISTORY.items():
        HOST_EVENT_HISTORY[host] = [
            t for t in timestamps if now - t <= TIME_WINDOW
        ]
        if len(HOST_EVENT_HISTORY[host]) > FLAP_THRESHOLD:
            print(f"\n⚠ Host {host} is FLAPPING excessively "
                  f"({len(HOST_EVENT_HISTORY[host])} moves in {TIME_WINDOW}s)\n")


class ControllerHandler(BaseHTTPRequestHandler):
    def do_POST(self):
        content_length = int(self.headers['Content-Length'])
        post_data = self.rfile.read(content_length)
        data = json.loads(post_data.decode())

        host = data.get("host")
        tor = data.get("tor")
        event = data.get("event")

        # =========================
        # ADDED: Track events
        # =========================
        now = time.time()
        EVENT_WINDOW.append(now)

        if host not in HOST_EVENT_HISTORY:
            HOST_EVENT_HISTORY[host] = []
        HOST_EVENT_HISTORY[host].append(now)

        # =========================
        # Existing logic (unchanged)
        # =========================
        if event == "join":
            HOST_LOCATIONS[host] = tor
        elif event == "leave":
            if HOST_LOCATIONS.get(host) == tor:
                HOST_LOCATIONS.pop(host, None)

        print("\n=== EVENT RECEIVED ===")
        print(f"Time: {datetime.now()}")
        print(f"Host: {host}")
        print(f"Event: {event}")
        print(f"ToR: {tor}")
        print(f"Current Map: {HOST_LOCATIONS}")
        print("======================")

        # =========================
        # ADDED: Health check
        # =========================
        check_network_health()

        self.send_response(200)
        self.end_headers()


def run():
    server = HTTPServer(("0.0.0.0", 5000), ControllerHandler)
    print("Controller running on port 5000...")
    server.serve_forever()


if __name__ == "__main__":
    run()