@echo off
echo [*] MQTT Test Client - Simulating GPS INSIDE geofence (NO ALERT)
echo.
echo This will publish GPS data INSIDE the safe zone every 5 seconds.
echo You should see:
echo   - Backend receives messages
echo   - Frontend marker updates
echo   - No geofence alerts
echo.
echo Press Ctrl+C to stop.
echo.

cd /d %~dp0
python test_mqtt_client.py

pause
