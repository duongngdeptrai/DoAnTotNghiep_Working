# Flutter application for Child Tracking

## Setup

1. Install Flutter SDK if not already installed
2. Run `flutter pub get` to install dependencies
3. For Android emulator, use `10.0.2.2` as backend host (points to localhost on host machine)
4. For physical device on same network, use your host machine's IP address

## Running the app

```bash
flutter run
```

## Build APK

```bash
flutter build apk --release
```

## Environment Variables

The app uses the following environment variables (can be set in build.gradle):
- BACKEND_HTTP_URL: Default `http://10.0.2.2:8000` for emulator
- BACKEND_WS_URL: Default `ws://10.0.2.2:8000/ws` for emulator
- DEFAULT_DEVICE_ID: Default `child_01`
- DEFAULT_LAT: Default `21.0285` (Hanoi)
- DEFAULT_LNG: Default `105.8542` (Hanoi)
- GEOFENCE_RADIUS_M: Default `100` (meters)