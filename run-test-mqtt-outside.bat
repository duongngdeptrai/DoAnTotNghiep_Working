@echo off
echo [*] MQTT Test Client - Simulating GPS OUTSIDE geofence (TRIGGERS ALERT)
echo.
echo This will publish GPS data that MOVES OUTSIDE the safe zone.
echo You should see:
echo   - Backend receives messages
echo   - Frontend marker moves outside circle
echo   - ONE Telegram/Email alert is sent
echo   - Frontend shows alert notification
echo.
echo Press Ctrl+C to stop.
echo.

cd /d %~dp0
python test_mqtt_client.py --move-outside

pause
