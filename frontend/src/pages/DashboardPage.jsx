import { useEffect, useState } from "react";
import TrackingMap from "../components/TrackingMap";
import GeofenceEditorPanel from "../components/GeofenceEditorPanel";
import { env } from "../config/env";
import { useTrackingSocket } from "../hooks/useTrackingSocket";
import { useGeofenceSharing } from "../hooks/useGeofenceSharing";
import {
  apiFetch,
  fetchDevices,
  fetchGeofenceState,
  postGeofenceFull,
  fetchLatest,
  postGeofenceMode,
  postGeofenceCenter,
  postGeofenceRadius,
  postGeofencePath,
} from "../lib/api";

function formatEpoch(epoch) {
  if (!epoch) {
    return "No data yet";
  }
  return new Date(epoch * 1000).toLocaleString();
}

const DEVICE_COLORS = [
  { primary: "#22d3ee", secondary: "#67e8f9" },
  { primary: "#a78bfa", secondary: "#c4b5fd" },
  { primary: "#34d399", secondary: "#6ee7b7" },
  { primary: "#f472b6", secondary: "#f9a8d4" },
  { primary: "#fb923c", secondary: "#fdba74" },
  { primary: "#60a5fa", secondary: "#93c5fd" },
  { primary: "#fbbf24", secondary: "#fcd34d" },
  { primary: "#f87171", secondary: "#fca5a5" },
];

function getDeviceColor(deviceId) {
  if (!deviceId) return DEVICE_COLORS[0];
  const index = deviceId.length % DEVICE_COLORS.length;
  return DEVICE_COLORS[index];
}

export default function DashboardPage({ selectedDeviceId, deviceRole }) {
  const [allDevices, setAllDevices] = useState([]);
  const [trackingDeviceIds, setTrackingDeviceIds] = useState(() => {
    const saved = localStorage.getItem("tracking_devices");
    return saved ? JSON.parse(saved) : selectedDeviceId ? [selectedDeviceId] : [];
  });
  const [locations, setLocations] = useState({});
  const [geofenceState, setGeofenceState] = useState({
    mode: "fixed",
    centerLat: env.defaultLat,
    centerLng: env.defaultLng,
    radiusM: env.geofenceRadiusM,
    source: "fixed",
    updatedAt: null,
    geofences: [],
  });
  const [shareEnabled, setShareEnabled] = useState(false);
  const [modeError, setModeError] = useState(null);
  const [alerts, setAlerts] = useState([]);
  const [showAlerts, setShowAlerts] = useState(false);
  const [showDeviceList, setShowDeviceList] = useState(false);
  const [focusedDeviceId, setFocusedDeviceId] = useState(null);
  const [isPlanMode, setIsPlanMode] = useState(false);
  const [editingGeofenceId, setEditingGeofenceId] = useState(null);
  const [newGeofenceName, setNewGeofenceName] = useState("");

  const [pendingConfig, setPendingConfig] = useState({
    name: "",
    mode: "circle",
    radius: 100,
    center: null,
    path: [],
  });

  const updatePendingConfig = (updates) => {
    setPendingConfig((prev) => ({ ...prev, ...updates }));
  };

  const removeLastPoint = () => {
    setPendingConfig((prev) => ({
      ...prev,
      path: prev.path ? prev.path.slice(0, -1) : [],
    }));
  };

  const handleCancelPlanMode = () => {
    if (editingGeofenceId) {
      const original = geofenceState.geofences?.find((g) => g.id === editingGeofenceId);
      const hasChanged =
        original?.name !== pendingConfig.name ||
        (original?.mode === "fixed" ? "circle" : "path") !== pendingConfig.mode ||
        original?.radiusM !== pendingConfig.radius ||
        JSON.stringify(original?.centerLat ? [original.centerLat, original.centerLng] : null) !==
          JSON.stringify(pendingConfig.center) ||
        JSON.stringify(original?.path) !== JSON.stringify(pendingConfig.path);

      if (hasChanged && !window.confirm("Bạn có chắc chắn muốn hủy bỏ các thay đổi?")) {
        return;
      }
    }
    setIsPlanMode(false);
    setEditingGeofenceId(null);
    setModeError(null);
  };

  const { latestMessage, status } = useTrackingSocket(env.backendWsUrl);
  const { sharingStatus, sharingError } = useGeofenceSharing(
    env.backendHttpUrl,
    shareEnabled,
    setGeofenceState,
  );

  const isOwner = deviceRole === "owner";
  const hasTracking = trackingDeviceIds.length > 0;

  useEffect(() => {
    localStorage.setItem("tracking_devices", JSON.stringify(trackingDeviceIds));
  }, [trackingDeviceIds]);

  useEffect(() => {
    if (!isOwner) {
      setShareEnabled(false);
    }
  }, [isOwner]);

  useEffect(() => {
    fetchDevices()
      .then((devices) => {
        setAllDevices(devices || []);
        const deviceIds = devices?.map((d) => d.deviceId) || [];
        if (deviceIds.length > 0 && trackingDeviceIds.length === 0) {
          setTrackingDeviceIds([deviceIds[0]]);
        }
      })
      .catch(() => undefined);
  }, []);

  useEffect(() => {
    fetchGeofenceState()
      .then((state) => setGeofenceState((prev) => ({ ...prev, ...state })))
      .catch(() => undefined);
  }, []);

  useEffect(() => {
    if (!latestMessage) return;

    if (latestMessage.type === "location_update" || latestMessage.type === "location") {
      const { deviceId, lat, lng, timestamp } = latestMessage;
      setLocations((prev) => ({
        ...prev,
        [deviceId]: { lat, lng, timestamp },
      }));
    }

    if (latestMessage.type === "alert" || latestMessage.type === "geofence_alert") {
      setAlerts((prev) => [latestMessage, ...prev].slice(0, 50));
    }

    if (latestMessage.type === "geofence_state_update") {
      setGeofenceState((prev) => ({ ...prev, ...latestMessage }));
    }
  }, [latestMessage]);

  const handleToggleTracking = (deviceId) => {
    setTrackingDeviceIds((prev) =>
      prev.includes(deviceId)
        ? prev.filter((id) => id !== deviceId)
        : [...prev, deviceId],
    );
  };

  const handleDeviceSelect = (deviceId) => {
    setFocusedDeviceId(deviceId);
  };

  const handleSaveGeofence = async () => {
    setModeError(null);
    try {
      if (editingGeofenceId) {
        await postGeofenceFull({
          geofence_id: editingGeofenceId,
          name: pendingConfig.name,
          mode: pendingConfig.mode,
          radius_m: pendingConfig.radius,
          lat: pendingConfig.center?.[0],
          lng: pendingConfig.center?.[1],
          path: pendingConfig.path,
        });
      } else {
        await postGeofenceFull({
          geofence_id: "default",
          name: pendingConfig.name || undefined,
          mode: pendingConfig.mode,
          radius_m: pendingConfig.radius,
          lat: pendingConfig.center?.[0],
          lng: pendingConfig.center?.[1],
          path: pendingConfig.path,
        });
      }
      setIsPlanMode(false);
      setEditingGeofenceId(null);
      setPendingConfig({ name: "", mode: "circle", radius: 100, center: null, path: [] });
      const updated = await fetchGeofenceState();
      setGeofenceState((prev) => ({ ...prev, ...updated }));
    } catch (err) {
      setModeError(err.message);
    }
  };

  const handleSetMode = async (mode) => {
    setModeError(null);
    try {
      const updated = await postGeofenceMode(mode);
      setGeofenceState((prev) => ({ ...prev, ...updated }));
    } catch (err) {
      setModeError(err.message);
    }
  };

  const handleSetCenter = async (lat, lng) => {
    setModeError(null);
    try {
      const updated = await postGeofenceCenter(lat, lng);
      setGeofenceState((prev) => ({ ...prev, ...updated }));
    } catch (err) {
      setModeError(err.message);
    }
  };

  const handleSetRadius = async (radius) => {
    setModeError(null);
    try {
      const updated = await postGeofenceRadius(radius);
      setGeofenceState((prev) => ({ ...prev, ...updated }));
    } catch (err) {
      setModeError(err.message);
    }
  };

  const handleSetPath = async (path) => {
    setModeError(null);
    try {
      const updated = await postGeofencePath(path);
      setGeofenceState((prev) => ({ ...prev, ...updated }));
    } catch (err) {
      setModeError(err.message);
    }
  };

  const handleStartPlanMode = () => {
    setIsPlanMode(true);
    setEditingGeofenceId(null);
    setPendingConfig({
      name: "",
      mode: geofenceState.mode === "mobile" ? "path" : "circle",
      radius: geofenceState.radiusM || 100,
      center: geofenceState.centerLat
        ? [geofenceState.centerLat, geofenceState.centerLng]
        : null,
      path: [],
    });
  };

  const handleEditGeofence = (geofence) => {
    setEditingGeofenceId(geofence.id);
    setPendingConfig({
      name: geofence.name || "",
      mode: geofence.mode === "mobile" ? "path" : "circle",
      radius: geofence.radiusM || 100,
      center: geofence.centerLat ? [geofence.centerLat, geofence.centerLng] : null,
      path: geofence.path || [],
    });
    setIsPlanMode(true);
  };

  const handleDeleteGeofence = async (geofenceId) => {
    setModeError(null);
    try {
      const updated = await apiFetch(
        `${env.backendHttpUrl}/geofence/${geofenceId}`,
        { method: "DELETE" },
      );
      setGeofenceState((prev) => ({ ...prev, ...updated }));
    } catch (err) {
      setModeError(err.message);
    }
  };

  const handleFetchLatest = async (deviceId) => {
    try {
      const data = await fetchLatest(deviceId);
      if (data) {
        setLocations((prev) => ({
          ...prev,
          [deviceId]: { lat: data.lat, lng: data.lng, timestamp: data.timestamp },
        }));
      }
    } catch {
      // ignore fetch errors for individual devices
    }
  };

  return (
    <section className="full-screen-map">
      <TrackingMap
        trackingDeviceIds={trackingDeviceIds}
        locations={locations}
        geofenceState={geofenceState}
        deviceColors={DEVICE_COLORS}
        focusedDeviceId={focusedDeviceId}
        onDeviceSelect={handleDeviceSelect}
        onMapClick={handleSetCenter}
        isPlanMode={isPlanMode}
        editingGeofenceId={editingGeofenceId}
        pendingConfig={pendingConfig}
        updatePendingConfig={updatePendingConfig}
        removeLastPoint={removeLastPoint}
      />

      <GeofenceEditorPanel
        geofenceState={geofenceState}
        isOwner={isOwner}
        isPlanMode={isPlanMode}
        editingGeofenceId={editingGeofenceId}
        pendingConfig={pendingConfig}
        modeError={modeError}
        onSetMode={handleSetMode}
        onStartPlanMode={handleStartPlanMode}
        onSaveGeofence={handleSaveGeofence}
        onCancelPlanMode={handleCancelPlanMode}
        onEditGeofence={handleEditGeofence}
        onDeleteGeofence={handleDeleteGeofence}
        onSetRadius={handleSetRadius}
        onSetPath={handleSetPath}
        updatePendingConfig={updatePendingConfig}
        removeLastPoint={removeLastPoint}
      />

      <div className="map-controls">
        <button
          className="control-button"
          onClick={() => setShowDeviceList(!showDeviceList)}
          title="Danh sách thiết bị"
        >
          📱
        </button>
        <button
          className="control-button"
          onClick={() => setShowAlerts(!showAlerts)}
          title="Cảnh báo"
        >
          🔔
          {alerts.length > 0 && (
            <span className="alert-badge">{alerts.length}</span>
          )}
        </button>
        <button
          className={`control-button ${shareEnabled ? "active" : ""}`}
          onClick={() => setShareEnabled(!shareEnabled)}
          title="Chia sẻ vị trí"
        >
          📤
        </button>
      </div>

      {showDeviceList && (
        <div className="device-list-panel">
          <div className="panel-header">
            <h4>Thiết bị theo dõi</h4>
            <button
              className="close-button"
              onClick={() => setShowDeviceList(false)}
            >
              ✕
            </button>
          </div>
          <div className="device-list">
            {allDevices.map((device) => (
              <div
                key={device.deviceId}
                className={`device-list-item ${
                  trackingDeviceIds.includes(device.deviceId) ? "tracking" : ""
                } ${selectedDeviceId === device.deviceId ? "selected" : ""}`}
                onClick={() => {
                  handleDeviceSelect(device.deviceId);
                  handleToggleTracking(device.deviceId);
                }}
              >
                <div
                  className="device-dot"
                  style={{ backgroundColor: getDeviceColor(device.deviceId).primary }}
                />
                <div className="device-info">
                  <span className="device-id">{device.deviceId}</span>
                  <span className="device-role">{device.role}</span>
                </div>
                <div className="device-status">
                  {trackingDeviceIds.includes(device.deviceId) ? (
                    <span className="status-on">Đang theo dõi</span>
                  ) : (
                    <span className="status-off">Không theo dõi</span>
                  )}
                </div>
              </div>
            ))}
          </div>
        </div>
      )}

      {showAlerts && (
        <div className="alerts-panel">
          <div className="panel-header">
            <h4>Cảnh báo</h4>
            <button
              className="close-button"
              onClick={() => setShowAlerts(false)}
            >
              ✕
            </button>
          </div>
          <div className="alerts-list">
            {alerts.length === 0 ? (
              <p className="muted">Không có cảnh báo</p>
            ) : (
              alerts.map((alert, idx) => (
                <div key={idx} className="alert-item">
                  <span className="alert-icon">⚠️</span>
                  <div className="alert-content">
                    <span className="alert-device">{alert.deviceId}</span>
                    <span className="alert-time">
                      {formatEpoch(alert.timestamp)}
                    </span>
                  </div>
                </div>
              ))
            )}
          </div>
        </div>
      )}

      {shareEnabled && (
        <div className="sharing-status">
          <span className="sharing-dot" />
          Đang chia sẻ vị trí...
        </div>
      )}

      {modeError && (
        <div className="error-toast">
          {modeError}
          <button onClick={() => setModeError(null)}>✕</button>
        </div>
      )}
    </section>
  );
}
