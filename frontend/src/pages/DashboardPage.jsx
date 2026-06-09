import { useEffect, useState } from "react";
import TrackingMap from "../components/TrackingMap";
import GeofenceEditorPanel from "../components/GeofenceEditorPanel";
import NotificationToast from "../components/NotificationToast";
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

function getEventMessage(event, deviceId, zoneName) {
  const zone = zoneName || "vùng an toàn";
  switch (event) {
    case "outside_entered":
      return `${deviceId} đã rời khỏi vùng an toàn`;
    case "outside_reminder":
      return `${deviceId} vẫn đang ngoài vùng an toàn`;
    case "inside_entered":
      return `${deviceId} đã đến ${zone}`;
    case "inside_moved":
      return `${deviceId} đã chuyển đến ${zone}`;
    default:
      return `Cảnh báo từ ${deviceId}`;
  }
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
  const [toastAlerts, setToastAlerts] = useState([]);
  const [unreadCount, setUnreadCount] = useState(0);
  const [showDeviceList, setShowDeviceList] = useState(true);
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

  const { latestMessage, status } = useTrackingSocket(env.backendWsUrl, trackingDeviceIds);
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
    trackingDeviceIds.forEach(async (deviceId) => {
      try {
        const data = await fetchLatest(deviceId);
        setLocations((prev) => ({
          ...prev,
          [deviceId]: data
            ? { lat: data.lat, lng: data.lng, timestamp: data.timestamp }
            : { lat: geofenceState.centerLat, lng: geofenceState.centerLng, timestamp: 0 },
        }));
      } catch {
        // ignore
      }
    });
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
      const zone = geofenceState.geofences?.find((g) => g.id === latestMessage.geofenceId);
      const zoneName = zone?.name || null;
      const toastId = Date.now() + Math.random();
      setToastAlerts((prev) => [...prev, { id: toastId, alert: latestMessage, zoneName }].slice(-3));
      setUnreadCount((prev) => prev + 1);
    }

    if (latestMessage.type === "geofence_state_update") {
      setGeofenceState((prev) => ({ ...prev, ...latestMessage }));
    }
  }, [latestMessage]);

  const handleToggleTracking = (deviceId) => {
    setTrackingDeviceIds((prev) =>
      prev.includes(deviceId) ? prev.filter((id) => id !== deviceId) : [...prev, deviceId],
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

  const handleToggleAlerts = () => {
    setShowAlerts((v) => {
      if (!v) setUnreadCount(0);
      return !v;
    });
  };

  const handleDismissToast = (toastId) => {
    setToastAlerts((prev) => prev.filter((t) => t.id !== toastId));
  };

  const handleTestToast = () => {
    const mockEvents = [
      { event: "outside_entered", deviceId: "child_01", geofenceId: null },
      { event: "inside_entered", deviceId: "child_01", geofenceId: geofenceState.geofences?.[0]?.id || null },
      { event: "outside_reminder", deviceId: "child_02", geofenceId: null },
      { event: "inside_moved", deviceId: "child_01", geofenceId: geofenceState.geofences?.[1]?.id || geofenceState.geofences?.[0]?.id || null },
    ];
    const mock = mockEvents[Math.floor(Math.random() * mockEvents.length)];
    const zone = geofenceState.geofences?.find((g) => g.id === mock.geofenceId);
    const toastId = Date.now() + Math.random();
    setToastAlerts((prev) => [...prev, { id: toastId, alert: { ...mock, timestamp: Math.floor(Date.now() / 1000) }, zoneName: zone?.name || null }].slice(-3));
    setAlerts((prev) => [{ type: "geofence_alert", ...mock, timestamp: Math.floor(Date.now() / 1000) }, ...prev].slice(0, 50));
    setUnreadCount((prev) => prev + 1);
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
        center={[geofenceState.centerLat, geofenceState.centerLng]}
        trackingDeviceIds={trackingDeviceIds}
        locations={locations}
        geofences={geofenceState.geofences}
        deviceColors={DEVICE_COLORS}
        focusedDeviceId={focusedDeviceId}
        onDeviceSelected={handleDeviceSelect}
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
          className={`control-button ${shareEnabled ? "active" : ""}`}
          onClick={() => setShareEnabled(!shareEnabled)}
          title="Chia sẻ vị trí"
        >
          📤
        </button>
        <button
          className="control-button"
          onClick={handleTestToast}
          title="Thử thông báo"
        >
          🧪
        </button>
      </div>

      <button
        className={`notification-bell-btn${unreadCount > 0 ? " has-alerts" : ""}`}
        onClick={() => alerts.length > 0 && handleToggleAlerts()}
        title={alerts.length > 0 ? "Xem thông báo" : "Không có thông báo"}
        style={{ cursor: alerts.length > 0 ? "pointer" : "default" }}
      >
        🔔
        {unreadCount > 0 && <span className="notification-bell-badge">{unreadCount}</span>}
      </button>

      {showDeviceList && (
        <div className="device-list-panel">
          <div className="device-list-header">
            <div>
              <h4>Thiết bị theo dõi</h4>
              {trackingDeviceIds.length > 0 && (
                <span className="device-count" style={{ fontSize: "11px" }}>
                  {trackingDeviceIds.length} đang theo dõi
                </span>
              )}
            </div>
            <button className="panel-close-btn" onClick={() => setShowDeviceList(false)}>✕</button>
          </div>
          <div className="device-list-content">
            {allDevices.length === 0 ? (
              <p className="muted" style={{ padding: "20px 16px", textAlign: "center", fontSize: "13px" }}>
                Chưa có thiết bị nào
              </p>
            ) : (
              allDevices.map((device) => {
                const isTracking = trackingDeviceIds.includes(device.deviceId);
                const isFocused = focusedDeviceId === device.deviceId;
                const color = getDeviceColor(device.deviceId);
                return (
                  <div
                    key={device.deviceId}
                    className={`device-list-item${isTracking ? " tracking" : ""}${isFocused ? " focused" : ""}`}
                    onClick={() => {
                      handleDeviceSelect(device.deviceId);
                      if (!isTracking) handleToggleTracking(device.deviceId);
                    }}
                    title="Click để chiếu đến vị trí"
                  >
                    <div
                      className="device-dot"
                      style={{
                        backgroundColor: color.primary,
                        boxShadow: isTracking ? `0 0 0 4px ${color.primary}28` : "none",
                      }}
                    />
                    <div className="device-info">
                      <span className="device-id">{device.deviceId}</span>
                      <span className="device-role">
                        {device.role === "owner" ? "Chủ sở hữu" : "Được chia sẻ"}
                      </span>
                    </div>
                    <button
                      className={isTracking ? "status-on" : "status-off"}
                      onClick={(e) => {
                        e.stopPropagation();
                        handleToggleTracking(device.deviceId);
                      }}
                      title={isTracking ? "Dừng theo dõi" : "Bắt đầu theo dõi"}
                    >
                      {isTracking ? "Đang theo dõi" : "Theo dõi"}
                    </button>
                  </div>
                );
              })
            )}
          </div>
        </div>
      )}

      {showAlerts && (
        <div className="alerts-panel">
          <div className="panel-header">
            <h4>Cảnh báo</h4>
            <button className="close-button" onClick={() => setShowAlerts(false)}>
              ✕
            </button>
          </div>
          <div className="alerts-list">
            {alerts.length === 0 ? (
              <p className="muted">Không có cảnh báo</p>
            ) : (
              alerts.map((alert, idx) => {
                const isOutside = alert.event?.startsWith("outside");
                const zone = geofenceState.geofences?.find((g) => g.id === alert.geofenceId);
                const msg = getEventMessage(alert.event, alert.deviceId, zone?.name);
                return (
                  <div key={idx} className={`alert-item ${isOutside ? "alert-outside" : "alert-inside"}`}>
                    <span className="alert-icon">{isOutside ? "⚠️" : "✅"}</span>
                    <div className="alert-content">
                      <span className="alert-message">{msg}</span>
                      <span className="alert-time">{formatEpoch(alert.timestamp)}</span>
                    </div>
                  </div>
                );
              })
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

      <NotificationToast toasts={toastAlerts} onDismiss={handleDismissToast} />
    </section>
  );
}
