@echo off
cd /d "%~dp0"
flutter build apk ^
  --dart-define=BACKEND_HTTP_URL=https://doantotnghiep-working.onrender.com ^
  --dart-define=BACKEND_WS_URL=wss://doantotnghiep-working.onrender.com/ws ^
  %*
