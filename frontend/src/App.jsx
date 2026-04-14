import { useEffect, useMemo, useState } from "react";
import TrackingMap from "./components/TrackingMap";
import { env } from "./config/env";
import { useTrackingSocket } from "./hooks/useTrackingSocket";

async function fetchLatest(deviceId) {
  const response = await fetch(`${env.backendHttpUrl}/latest/${deviceId}`);
  if (!response.ok) {
    return null;
  }
  return response.json();
}

export default function App() {
  const [markerPosition, setMarkerPosition] = useState([env.defaultLat, env.defaultLng]);
  const [insideGeofence, setInsideGeofence] = useState(true);
  const [lastUpdated, setLastUpdated] = useState(null);
  const [alerts, setAlerts] = useState([]);

  const { latestMessage, status } = useTrackingSocket(env.backendWsUrl);

  useEffect(() => {
    fetchLatest(env.deviceId).then((latest) => {
      if (!latest) return;
      setMarkerPosition([latest.lat, latest.lng]);
      setInsideGeofence(Boolean(latest.insideGeofence));
      setLastUpdated(latest.timestamp);
    });
  }, []);

  useEffect(() => {
    if (!latestMessage) return;

    if (latestMessage.type === "location_update" && latestMessage.deviceId === env.deviceId) {
      setMarkerPosition([latestMessage.lat, latestMessage.lng]);
      setInsideGeofence(Boolean(latestMessage.insideGeofence));
      setLastUpdated(latestMessage.timestamp);
    }

    if (latestMessage.type === "geofence_alert" && latestMessage.deviceId === env.deviceId) {
      setAlerts((prev) => [latestMessage, ...prev].slice(0, 10));
    }
  }, [latestMessage]);

  const statusClass = useMemo(() => {
    if (status === "connected") return "ok";
    if (status === "connecting") return "warning";
    return "error";
  }, [status]);

  return (
    <div className="page">
      <header className="header">
        <div>
          <h1>Child Tracking Dashboard</h1>
          <p>Real-time GPS monitor for device: {env.deviceId}</p>
        </div>
        <div className={`badge ${statusClass}`}>WS: {status}</div>
      </header>

      <section className="status-grid">
        <article className="card">
          <h3>Geofence</h3>
          <p className={insideGeofence ? "inside" : "outside"}>
            {insideGeofence ? "Inside safe zone" : "Outside safe zone"}
          </p>
        </article>
        <article className="card">
          <h3>Last update (epoch)</h3>
          <p>{lastUpdated ?? "No data yet"}</p>
        </article>
      </section>

      <section className="map-wrap">
        <TrackingMap
          center={[env.defaultLat, env.defaultLng]}
          markerPosition={markerPosition}
          geofenceRadiusM={env.geofenceRadiusM}
        />
      </section>

      <section className="alerts">
        <h3>Recent alerts</h3>
        {alerts.length === 0 ? (
          <p>No alerts.</p>
        ) : (
          <ul>
            {alerts.map((item, index) => (
              <li key={`${item.timestamp}-${index}`}>
                {item.event} at ({item.lat}, {item.lng}) ts={item.timestamp}
              </li>
            ))}
          </ul>
        )}
      </section>
    </div>
  );
}
