# Architecture Notes

## Processing Pipeline

1. MQTT message arrives on topic `gps/#`.
2. Backend parses and validates payload.
3. Noise filter ignores movement smaller than 5m.
4. Geofence service computes distance using Haversine formula.
5. Backend stores location in MongoDB collection `locations`.
6. Alert state service decides if alert should be fired.
7. Notification service sends Telegram and Email alerts.
8. WebSocket manager broadcasts real-time updates to clients.

## Alert Strategy

- Geofence center and radius are configurable.
- Alert fires on state transition `inside -> outside`.
- Optional reminder can fire again after cooldown when `outside` persists.
- No alert spam while staying outside unless reminder mode is enabled.

## Key Reliability Choices

- MQTT auto reconnect via `paho-mqtt` loop.
- Mongo unique key to suppress duplicate telemetry.
- Frontend WebSocket auto reconnect every 2 seconds.
- Backend components split by responsibility for easier testing.
