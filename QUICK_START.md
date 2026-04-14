# QUICK START - 5 Minute Demo

**You are here:** Demo guide for running the system without ESP32 hardware.

## 3-Command Start

### Terminal 1: Infrastructure
```bash
run-infra.bat
```
Wait for: `[+] Docker containers started!`

### Terminal 2: Backend  
```bash
run-backend.bat
```
Wait for: `=== STARTUP COMPLETE ===`

### Terminal 3: Frontend
```bash
run-frontend.bat
```
Wait for: `➜  Local:   http://localhost:5173/`

### Terminal 4: Simulate GPS (choose one)

**Option A - No Alert (stays inside geofence ~21.0285, 105.8542 ±50m):**
```bash
run-test-mqtt-inside.bat
```

**Option B - Alert Triggered (moves north, crosses 100m boundary):**
```bash
run-test-mqtt-outside.bat
```

Then open: **http://localhost:5173**

---

## File Reference

| File | Purpose |
|------|---------|
| [DEMO_STEPS.md](DEMO_STEPS.md) | Detailed walkthrough with expected outputs |
| [README.md](README.md) | Architecture & full setup |
| [backend/](backend/) | FastAPI service (MQTT, geofence, alerts, WebSocket) |
| [frontend/src/](frontend/src/) | React + Leaflet map UI |
| [test_mqtt_client.py](test_mqtt_client.py) | GPS simulator (replaces ESP32) |
| [run-*.bat](run-infra.bat) | Batch scripts to run each part |

---

## What You'll See

✅ **Map with blue geofence circle**  
✅ **Red marker moves in real-time**  
✅ **Status: "Inside safe zone" or "Outside safe zone"**  
✅ **Alert notification when crossing boundary** (with timestamps)  

Entire roundtrip latency: **< 1 second** from GPS → MQTT → Backend → Frontend

---

## Stop Everything

```bash
stop-demo.bat
```

Or manually: `docker compose down`

---

📖 **Need details?** See [DEMO_STEPS.md](DEMO_STEPS.md)  
🏗️ **Need architecture?** See [docs/architecture.md](docs/architecture.md)  
📝 **Need to code?** Backend in [backend/app/](backend/app/), Frontend in [frontend/src/](frontend/src/)
