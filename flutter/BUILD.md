# Flutter Build Guide

## Backend URLs

- HTTP: `https://doantotnghiep-working.onrender.com`
- WebSocket: `wss://doantotnghiep-working.onrender.com/ws`
- Default device: `child_01`

## Quick Build (Windows)

Double-click hoặc chạy từ terminal:

```bat
build_run.bat       # Run debug trên thiết bị/emulator
build_apk.bat       # Build APK release
```

Scripts tự động thêm 2 `--dart-define` flags — không cần gõ tay.

## Manual Build

```bash
flutter run --dart-define=BACKEND_HTTP_URL=https://doantotnghiep-working.onrender.com --dart-define=BACKEND_WS_URL=wss://doantotnghiep-working.onrender.com/ws

flutter build apk --dart-define=BACKEND_HTTP_URL=https://doantotnghiep-working.onrender.com --dart-define=BACKEND_WS_URL=wss://doantotnghiep-working.onrender.com/ws
```

## Luu y

- Moi lan build **bat buoc** co 2 `--dart-define` nay. Neu khong, app dung IP local (`192.168.76.41:9000`) va ket noi that bai.
- WebSocket dung `wss://` (khong phai `ws://`) vi Render chay HTTPS.
