import subprocess
import time
import requests
import socket
import sys

# ===== CONFIG =====
CONTROLLER_HOST = "clab-warehouse-evpn-management"
CONTROLLER_PORT = 5000
WATCHED_HOST = "host1"
POLL_INTERVAL = 1  # seconds
# ==================

tor_name = socket.gethostname()
host_present = False


def log(msg):
    print(f"[{tor_name}] {msg}", flush=True)


def namespace_exists():
    """
    Check if the watched namespace exists on this ToR.
    """
    try:
        result = subprocess.run(
            ["ip", "netns", "list"],
            capture_output=True,
            text=True,
            check=False
        )
        return WATCHED_HOST in result.stdout
    except Exception as e:
        log(f"Error checking namespace: {e}")
        return False


def send_event(event_type):
    """
    Send join/leave event to controller.
    """
    payload = {
        "host": WATCHED_HOST,
        "tor": tor_name,
        "event": event_type
    }

    try:
        response = requests.post(
            f"http://{CONTROLLER_HOST}:{CONTROLLER_PORT}",
            json=payload,
            timeout=2
        )
        if response.status_code == 200:
            log(f"Sent {event_type} event to controller")
        else:
            log(f"Controller responded with status {response.status_code}")
    except requests.exceptions.RequestException as e:
        log(f"Controller unreachable: {e}")


def main():
    global host_present

    log("ToR mobility agent started")

    while True:
        current_state = namespace_exists()

        # Host joined
        if current_state and not host_present:
            log("Detected host JOIN")
            send_event("join")
            host_present = True

        # Host left
        elif not current_state and host_present:
            log("Detected host LEAVE")
            send_event("leave")
            host_present = False

        time.sleep(POLL_INTERVAL)


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        log("Agent stopped")
        sys.exit(0)