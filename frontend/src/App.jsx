import { useEffect, useMemo, useState } from "react";
import TrackingMap from "./components/TrackingMap";
import { env } from "./config/env";
import { useTrackingSocket } from "./hooks/useTrackingSocket";
import { useGeofenceSharing } from "./hooks/useGeofenceSharing";

async function fetchLatest(deviceId) {
  const response = await fetch(`${env.backendHttpUrl}/latest/${deviceId}`);
  if (!response.ok) {
    return null;
  }
  return response.json();
}

async function fetchGeofenceState() {
  const response = await fetch(`${env.backendHttpUrl}/geofence/state`);
  if (!response.ok) {
    return null;
  }
  return response.json();
}

async function postGeofenceMode(mode) {
  const response = await fetch(`${env.backendHttpUrl}/geofence/mode`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ mode }),
  });

  if (!response.ok) {
    throw new Error(`Khong the cap nhat geofence mode: ${response.status}`);
  }

  return response.json();
}

function formatEpoch(epoch) {
  if (!epoch) {
    return "No data yet";
  }

  return new Date(epoch * 1000).toLocaleString();
}

export default function App() {
  const [markerPosition, setMarkerPosition] = useState([env.defaultLat, env.defaultLng]);
  const [insideGeofence, setInsideGeofence] = useState(true);
  const [lastUpdated, setLastUpdated] = useState(null);
  const [geofenceState, setGeofenceState] = useState({
    mode: "fixed",
    centerLat: env.defaultLat,
    centerLng: env.defaultLng,
    radiusM: env.geofenceRadiusM,
    source: "fixed",
    updatedAt: null,
  });
  const [shareEnabled, setShareEnabled] = useState(false);
  const [modeError, setModeError] = useState(null);
  const [alerts, setAlerts] = useState([]);

  const { latestMessage, status } = useTrackingSocket(env.backendWsUrl);
  const { sharingStatus, sharingError } = useGeofenceSharing(
    env.backendHttpUrl,
    shareEnabled,
    setGeofenceState,
  );

  useEffect(() => {
    fetchLatest(env.deviceId).then((latest) => {
      if (!latest) return;
      setMarkerPosition([latest.lat, latest.lng]);
      setInsideGeofence(Boolean(latest.insideGeofence));
      setLastUpdated(latest.timestamp);
    });
  }, []);

  useEffect(() => {
    fetchGeofenceState().then((state) => {
      if (!state) {
        return;
      }

      setGeofenceState(state);
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

    if (latestMessage.type === "geofence_state_update") {
      setGeofenceState(latestMessage);
    }
  }, [latestMessage]);

  const handleFixedMode = async () => {
    setModeError(null);
    setShareEnabled(false);

    try {
      const state = await postGeofenceMode("fixed");
      setGeofenceState(state);
    } catch (error) {
      setModeError(error instanceof Error ? error.message : "Khong the chuyen ve che do co dinh.");
    }
  };

  const handleMobileMode = async () => {
    setModeError(null);

    try {
      const state = await postGeofenceMode("mobile");
      setGeofenceState(state);
      setShareEnabled(true);
    } catch (error) {
      setModeError(error instanceof Error ? error.message : "Khong the chuyen sang che do di dong.");
    }
  };

  const statusClass = useMemo(() => {
    if (status === "connected") return "ok";
    if (status === "connecting") return "warning";
    return "error";
  }, [status]);

  const center = [geofenceState.centerLat, geofenceState.centerLng];

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
          <p className="muted">Mode: {geofenceState.mode}</p>
        </article>
        <article className="card">
          <h3>Last update (epoch)</h3>
          <p>{formatEpoch(lastUpdated)}</p>
        </article>
        <article className="card">
          <h3>Safe zone center</h3>
          <p>
            {geofenceState.centerLat?.toFixed(6)}, {geofenceState.centerLng?.toFixed(6)}
          </p>
          <p className="muted">Source: {geofenceState.source}</p>
          <p className="muted">Updated: {formatEpoch(geofenceState.updatedAt)}</p>
        </article>
      </section>

      <section className="card control-panel">
        <div className="control-header">
          <div>
            <h3>Safe zone control</h3>
            <p className="muted">Fixed mode uses the configured center. Mobile mode follows this phone.</p>
          </div>
          <div className={`badge ${geofenceState.mode === "mobile" ? "warning" : "ok"}`}>
            {geofenceState.mode}
          </div>
        </div>

        <div className="button-row">
          <button className="primary-button" onClick={handleFixedMode} type="button">
            Use fixed center
          </button>
          <button className="secondary-button" onClick={handleMobileMode} type="button">
            Use this phone as center
          </button>
        </div>

        <div className="control-meta">
          <span className={`chip ${sharingStatus}`}>Phone share: {sharingStatus}</span>
          <span className="chip">Radius: {geofenceState.radiusM} m</span>
        </div>

        {(modeError || sharingError) && (
          <p className="error-text">{modeError || sharingError}</p>
        )}
      </section>

      <section className="map-wrap">
        <TrackingMap
          center={center}
          markerPosition={markerPosition}
          geofenceRadiusM={geofenceState.radiusM}
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
