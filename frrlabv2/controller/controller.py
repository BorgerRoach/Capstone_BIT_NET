import socket
import json

HOST = "0.0.0.0"
PORT = 5000

print(f"[controller] Starting on {HOST}:{PORT}")

try:
    server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    server.bind((HOST, PORT))
    server.listen(10)
    print("[controller] Listening for agent events...")
except Exception as e:
    print(f"[controller] Failed to start: {e}")
    exit(1)

while True:
    try:
        conn, addr = server.accept()
        data = conn.recv(4096)

        if not data:
            conn.close()
            continue

        try:
            msg = json.loads(data.decode())
            print("\n=== EVENT RECEIVED ===")
            for k, v in msg.items():
                print(f"{k}: {v}")
            print("======================\n")
        except Exception as e:
            print(f"[controller] JSON parse error: {e}")
            print("Raw data:", data)

        conn.close()

    except KeyboardInterrupt:
        print("\n[controller] Shutting down")
        break
    except Exception as e:
        print(f"[controller] Runtime error: {e}")
