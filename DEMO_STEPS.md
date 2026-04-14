# DEMO STEPS - Run Without ESP32

This guide walks through a complete end-to-end demo of the child tracking system without physical hardware.

## Prerequisites Check

Before starting, ensure:
- [ ] Python 3.10+ installed (`python --version`)
- [ ] Node.js 18+ installed (`node --version`)
- [ ] Docker Desktop is installed and running
- [ ] PowerShell or Command Prompt available

## Demo Timeline: ~10 minutes

### Phase 1: Infrastructure (2 min)

**Step 1a: Open Command Prompt/PowerShell**
- Press `Win + R`, type `cmd` or `powershell`, press Enter
- Navigate to project root: `cd "D:\Do An Tot Nghiep"`

**Step 1b: Start Docker Containers**
```cmd
run-infra.bat
```

Expected output:
```
[+] Running 2/2
 ✓ Container child-tracking-mongo  Started
 ✓ Container child-tracking-mqtt   Started
```

Wait for message: **"MongoDB is ready"** and **"Mosquitto MQTT is ready"**

---

### Phase 2: Backend (3 min)

**Step 2a: Open NEW Command Prompt/PowerShell**
- Press `Win + R`, type `cmd`, press Enter
- Navigate to project: `cd "D:\Do An Tot Nghiep"`

**Step 2b: Start Backend**
```cmd
run-backend.bat
```

Expected output during first run:
```
[*] Installing dependencies...
Collecting fastapi...
...
[+] Starting FastAPI backend on http://0.0.0.0:8000
INFO:     Uvicorn running on http://0.0.0.0:8000
```

Do NOT close this terminal.

---

### Phase 3: Frontend (2 min)

**Step 3a: Open NEW Command Prompt/PowerShell**
- Press `Win + R`, type `cmd`, press Enter
- Navigate to project: `cd "D:\Do An Tot Nghiep"`

**Step 3b: Start Frontend**
```cmd
run-frontend.bat
```

Expected output during first run:
```
[*] Installing npm dependencies...
npm notice...
[+] Starting React frontend on http://localhost:5173
```

Watch for:
```
  ➜  Local:   http://localhost:5173/
```

---

### Phase 4: Open Browser (1 min)

**Step 4a: Open Dashboard**
- Click Start menu, open Firefox or Chrome
- Navigate to: `http://localhost:5173`

Expected to see:
- Header: "Child Tracking Dashboard"
- Map in center
- Blue circle (geofence)
- Red "WS: connecting" badge at top-right

After ~2 seconds:
- Badge turns green: "WS: connected"
- Text in status says: "Inside safe zone"

---

### Phase 5: Test INSIDE Geofence (2 min - No Alert)

**Step 5a: Open NEW Command Prompt/PowerShell**
- Press `Win + R`, type `cmd`, press Enter
- Navigate to project: `cd "D:\Do An Tot Nghiep"`

**Step 5b: Run GPS Simulator - INSIDE Mode**
```cmd
run-test-mqtt-inside.bat
```

Expected output:
```
[*] MQTT Test Client - Simulating GPS INSIDE geofence (NO ALERT)

GEOFENCE INFO (from backend config):
  Center: (21.0285, 105.8542)
  Radius: 100m

MODE: Staying INSIDE geofence (no alert)

[0000] 🟢 inside | lat=21.028500 lng=105.854200 dis=0m
[0001] 🟢 inside | lat=21.028501 lng=105.854201 dis=0m
[0002] 🟢 inside | lat=21.028502 lng=105.854202 dis=0m
```

**Observe in browser:**
- Marker on map updates position (small moves near center)
- Status shows: "Inside safe zone" (green)
- No alerts in bottom section
- Backend console shows: `INFO Processing: child_01 at lat=21.0285...`

Let this run for ~30 seconds to see multiple updates.

**Press Ctrl+C** in this terminal to stop.

---

### Phase 6: Test OUTSIDE Geofence (3 min - Triggers Alert!)

**Step 6a: Run GPS Simulator - OUTSIDE Mode**
```cmd
run-test-mqtt-outside.bat
```

Expected output:
```
[*] MQTT Test Client - Simulating GPS OUTSIDE geofence (TRIGGERS ALERT)

MODE: Moving OUTSIDE geofence (should trigger alert)

[0000] 🟢 inside | lat=21.028500 lng=105.854200 dis=0m
[0001] 🟢 inside | lat=21.028501 lng=105.854201 dis=0m
[0002] 🟢 inside | lat=21.028602 lng=105.854200 dis=100m
[0003] 🔴 OUTSIDE | lat=21.028702 lng=105.854200 dis=150m
[0004] 🔴 OUTSIDE | lat=21.028802 lng=105.854200 dis=200m
```

**Watch the magic in browser:**

1. **After message [0002]** - Marker moves outside the circle
   - Geofence status changes to: "Outside safe zone" (red)
   - Backend log: `[KEY] ALERT TRIGGERED: child_01 event=outside_entered`

2. **Alerts section shows:**
   - `outside_entered at (21.0286, 105.8542) ts=...`

3. **Notifications sent (if configured):**
   - Backend log: `Failed to send Telegram alert:` (expected if no token set)
   - This is OK for demo - just shows it tried to send

4. **Continue watching:**
   - Marker keeps moving north (visually outside the circle)
   - Status still: "Outside safe zone"
   - NO MORE ALERTS (this is correct - only one alert on state change!)
   - After 60 seconds, if `ALERT_REPEAT_OUTSIDE=true`, would send reminder

Let this run for ~1-2 minutes to see behavior.

**Press Ctrl+C** to stop.

---

## What You've Demonstrated

✅ **Real-time GPS data flow:**
- Test client simulates ESP32
- MQTT publish to broker
- Backend receives and processes
- Frontend shows in real-time (< 1 second latency)

✅ **Geofence detection:**
- Haversine distance calculation works
- Inside/outside state tracked correctly
- Circle on map matches 100m radius

✅ **Anti-spam alerts:**
- Alert fires ONCE on state change
- No duplicate alerts while staying outside
- Perfect for production use

✅ **WebSocket real-time:**
- Marker moves without page reload
- Connection auto-reconnects if lost
- Messages pushed instantly

✅ **Data persistence:**
- Locations stored in MongoDB
- Can query history via `/history/{device_id}`

---

## Advanced Testing (Optional)

### Test History API
Open new terminal:
```cmd
curl http://localhost:8000/history/child_01
```

Output: JSON array of latest 100 locations.

### Test Latest API
```cmd
curl http://localhost:8000/latest/child_01
```

Output: Most recent location.

### Test Swagger UI
- Open: http://localhost:8000/docs
- Try endpoints interactively

### Custom GPS Coordinates
```cmd
python test_mqtt_client.py --lat 20.9 --lng 105.8 --move-outside
```

Lower latitude (20.9) is much further south, will be detected as outside.

---

## Cleanup

When done, stop everything:

**Option 1: Use cleanup script**
```cmd
stop-demo.bat
```

**Option 2: Manual**
- Close all terminal windows (Ctrl+C to stop each service)
- Then: `docker compose down`

---

## Troubleshooting

### "Backend fails to connect to MongoDB"
- Check Docker is running: `docker ps`
- Restart containers: `docker compose restart mongo`

### "Frontend shows 'WS: error' for >10 seconds"
- Backend may not be running - check terminal 2
- Ensure backend shows: `Uvicorn running on...`

### "No marker updates in browser"
- Open browser DevTools (F12)
- Check Console tab for JS errors
- Check Network tab - should show WebSocket connection

### "Test client says 'Connection refused'"
- Mosquitto container may not be ready
- Wait 10 seconds and try again
- Or restart everything with `stop-demo.bat && run-infra.bat`

### "ModuleNotFoundError: No module named 'paho'"
- Backend installation failed
- In backend terminal, run: `pip install -r requirements.txt`

---

## Next Steps for Production

1. **Enable Telegram Alerts:**
   - Get bot token from BotFather on Telegram
   - Edit backend/.env: `TELEGRAM_BOT_TOKEN=...`
   - Restart backend

2. **Enable Email Alerts:**
   - Use Gmail app-specific password
   - Edit backend/.env: `SMTP_USERNAME=your_email@gmail.com`

3. **Deploy Backend:**
   - `docker build -f backend/Dockerfile .`
   - Push to production server

4. **Deploy Frontend:**
   - `npm run build`
   - Host dist/ folder on web server

5. **Flash ESP32:**
   - Edit esp32-firmware/child_tracker.ino with Wi-Fi credentials
   - Flash to physical device
   - Runs independently, no changes needed

---

Enjoy the demo! 🎉
