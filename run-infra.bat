@echo off
REM Start Docker containers for MongoDB and Mosquitto
echo [*] Starting Docker containers...
docker compose up -d

REM Wait for services to be ready
timeout /t 5

echo [+] Docker containers started!
echo.
echo MongoDB is ready at: mongodb://localhost:27017
echo Mosquitto MQTT is ready at: localhost:1883
echo.
echo Next steps:
echo   1. Open new terminal and run: run-backend.bat
echo   2. Open new terminal and run: run-frontend.bat
echo   3. Open new terminal and run: run-test-mqtt.bat
echo.
pause

