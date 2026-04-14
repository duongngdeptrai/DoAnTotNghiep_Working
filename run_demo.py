#!/usr/bin/env python3
"""
Demo script to fully simulate the tracking system without ESP32.
Runs docker containers, publishes test GPS data, and provides test scenarios.
"""

import subprocess
import time
import sys
import os


def run_command(cmd, description="Running command"):
    """Run shell command and print output."""
    print(f"\n[*] {description}")
    print(f"    Command: {cmd}")
    result = subprocess.run(cmd, shell=True, capture_output=False)
    if result.returncode != 0:
        print(f"[!] Command failed with code {result.returncode}")
        return False
    return True


def print_section(title):
    """Print section header."""
    print("\n" + "=" * 60)
    print(f"  {title}")
    print("=" * 60)


def main():
    root_dir = os.path.dirname(os.path.abspath(__file__))

    print_section("CHILD TRACKING SYSTEM - FULL DEMO SETUP")

    print("\nStep 1: Start Docker containers (MongoDB + Mosquitto)")
    print("  Command: docker compose up -d")
    if not run_command(f"cd {root_dir} && docker compose up -d", "Starting Docker containers"):
        print("[!] Failed to start Docker. Ensure Docker is installed and running.")
        return False

    print("\n[+] Waiting 5s for services to be ready...")
    time.sleep(5)

    print_section("DEMO READY")
    print("""
Now run each part in separate terminals:

[Terminal 1] Backend:
  cd backend
  pip install -r requirements.txt
  copy .env.example .env
  uvicorn app.main:app --reload --host 0.0.0.0 --port 8000

[Terminal 2] Frontend:
  cd frontend
  npm install
  copy .env.example .env
  npm run dev

[Terminal 3] MQTT test client (inside "inside" geofence - NO ALERT):
  python test_mqtt_client.py

[Terminal 4] MQTT test client (move OUTSIDE geofence - TRIGGERS ALERT):
  python test_mqtt_client.py --move-outside

Then open browser:
  http://localhost:5173
""")

    print("\nTo stop everything:")
    print("  docker compose down")


if __name__ == "__main__":
    main()
