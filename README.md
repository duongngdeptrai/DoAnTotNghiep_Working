# Real-time Child Tracking System

Full-stack IoT system using ESP32, MQTT, FastAPI, MongoDB, WebSocket, and React + Leaflet.

## Quick Demo (No Hardware Required)

### Prerequisites
- Python 3.10+
- Node.js 18+
- Docker + Docker Compose
- Git Bash or PowerShell

### Run in 4 Steps (Windows)

**Step 1: Start Infrastructure**
```bash
run-infra.bat
```
Starts MongoDB (localhost:27017) and Mosquitto (localhost:1883).

**Step 2: Terminal 1 - Backend**
```bash
run-backend.bat
```
Installs dependencies and starts FastAPI at http://localhost:8000.

**Step 3: Terminal 2 - Frontend**
```bash
run-frontend.bat
```
Installs dependencies and starts React at http://localhost:5173.

**Step 4: Terminal 3 - Simulate GPS**

Option A: GPS inside safe zone (no alert):
```bash
run-test-mqtt-inside.bat
```

Option B: GPS moving outside (triggers alert):
```bash
run-test-mqtt-outside.bat
```

### See It Work
1. Open browser: http://localhost:5173
2. Watch marker move on map in real-time
3. If using outside mode, geofence circle turns red and alert appears
4. Check console for MQTT/backend logs

### Cleanup
```bash
stop-demo.bat
```

## Project Structure

```
Do An Tot Nghiep/
├── backend/
│   ├── app/
│   │   ├── api/                # REST endpoints
│   │   ├── core/               # App settings
│   │   ├── db/                 # Mongo connection
│   │   ├── models/             # Pydantic models
│   │   ├── repositories/       # Database operations
│   │   ├── services/           # MQTT, geofence, notifier, processor
│   │   ├── ws/                 # WebSocket manager
│   │   └── main.py             # FastAPI entrypoint
│   ├── .env.example
│   └── requirements.txt
├── frontend/
│   ├── src/
│   │   ├── components/         # React map components
│   │   ├── config/             # Frontend env config
│   │   ├── hooks/              # WebSocket hook
│   │   ├── App.jsx
│   │   ├── main.jsx
│   │   └── styles.css
│   ├── .env.example
│   ├── package.json
│   └── vite.config.js
├── esp32-firmware/
│   └── child_tracker.ino
├── infra/
│   └── mosquitto/
├── docker-compose.yml
└── docs/
    └── architecture.md
```

## 1) Start Infrastructure

```bash
docker compose up -d
```

This starts:
- MongoDB at `mongodb://localhost:27017`
- MQTT broker at `localhost:1883`

## 2) Run Backend

```bash
cd backend
python -m venv .venv
.venv\\Scripts\\activate
pip install -r requirements.txt
copy .env.example .env
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

## 3) Run Frontend

```bash
cd frontend
npm install
copy .env.example .env
npm run dev
```

Open: `http://localhost:5173`

## 4) Flash ESP32

- Open `esp32-firmware/child_tracker.ino` in Arduino IDE
- Update Wi-Fi and MQTT constants
- Upload and monitor serial logs

## Data Flow

ESP32 GPS -> MQTT topic `gps/{deviceId}` -> FastAPI subscriber -> MongoDB + Geofence checks -> Telegram/Email alerts -> WebSocket -> React map.

The safe zone can run in two modes:
- `fixed`: use the configured center from backend settings.
- `mobile`: use the current phone/browser location as the center and keep updating it.

Frontend geofence endpoints:
- `GET /geofence/state`
- `POST /geofence/mode` with `{ "mode": "fixed" | "mobile" }`
- `POST /geofence/center` with `{ "lat": number, "lng": number }`

## API Endpoints

- `GET /health`
- `GET /geofence/state`
- `POST /geofence/mode`
- `POST /geofence/center`
- `GET /latest/{device_id}`
- `GET /history/{device_id}?limit=100`
- `WS /ws`
