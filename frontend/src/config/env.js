export const env = {
  backendHttpUrl: import.meta.env.VITE_BACKEND_HTTP_URL || "http://localhost:9000",
  backendWsUrl: import.meta.env.VITE_BACKEND_WS_URL || "ws://localhost:9000/ws",
  deviceId: import.meta.env.VITE_DEVICE_ID || "child_01",
  defaultLat: Number(import.meta.env.VITE_DEFAULT_LAT || 21.0285),
  defaultLng: Number(import.meta.env.VITE_DEFAULT_LNG || 105.8542),
  geofenceRadiusM: Number(import.meta.env.VITE_GEOFENCE_RADIUS_M || 100),
};
