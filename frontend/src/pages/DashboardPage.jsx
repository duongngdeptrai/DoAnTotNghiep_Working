import { useEffect, useMemo, useState } from "react";
import TrackingMap from "../components/TrackingMap";
import GeofenceEditorPanel from "../components/GeofenceEditorPanel";
import { env } from "../config/env";
import { useTrackingSocket } from "../hooks/useTrackingSocket";
import { useGeofenceSharing } from "../hooks/useGeofenceSharing";
import {
  authLogin,
  authRegister,
  fetchDevices,
  fetchMe,
  fetchGeofenceState,
  postGeofenceFull,
  fetchLatest,
  postGeofenceMode,
  postGeofenceCenter,
  postGeofenceRadius,
  postGeofencePath,
  registerDevice,
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

export default function DashboardPage({ token, selectedDeviceId, deviceRole }) {
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
      const original = geofenceState.geofences?.find(g => g.id === editingGeofenceId);
      const hasChanged =
        original?.name !== pendingConfig.name ||
        (original?.mode === 'fixed' ? 'circle' : 'path') !== pendingConfig.mode ||
        original?.radius_m !== pendingConfig.radius ||
        JSON.stringify(original?.centerLat ? [original.centerLat, original.centerLng] : null) !== JSON.stringify(pendingConfig.center) ||
        JSON.stringify(original?.path) !== JSON.stringify(pendingConfig.path);

      if (hasChanged && !window.confirm("Bạn có chắc chắn muốn hủy bỏ các thay đổi?")) {
        return;
      }
    }
    setIsPlanMode(false);
    setEditingGeofenceId(null);
    setModeError(null);
  };


  const { latestMessage, status } = useTrackingSocket(token ? env.backendWsUrl : null, token);
  const { sharingStatus, sharingError } = useGeofenceSharing(
    env.backendHttpUrl,
    shareEnabled,
    setGeofenceState,
    token,
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
    if (!token) {
      return;
    }
    fetchDevices(token)
      .then((devices) => {
        setAllDevices(devices || []);
        const deviceIds = devices?.map((d) => d.deviceId) || [];
        if (deviceIds.length > 0 && trackingDeviceIds.length === 0) {
          setTrackingDeviceIds([deviceIds[0]]);
        }
      })
      .catch(() => undefined);
  }, [token]);

  useEffect(() => {
    if (!token || trackingDeviceIds.length === 0) {
      return;
    }
    const promises = trackingDeviceIds.map((deviceId) =>
      fetchLatest(token, deviceId).then((latest) => {
        if (latest) {
          setLocations((prev) => ({
            ...prev,
            [deviceId]: {
              lat: latest.lat,
              lng: latest.lng,
              insideGeofence: latest.insideGeofence,
              timestamp: latest.timestamp,
            },
          }));
        }
      }).catch(() => undefined)
    );
    Promise.all(promises);
  }, [token, trackingDeviceIds]);

  useEffect(() => {
    setAlerts([]);
  }, [trackingDeviceIds]);

  useEffect(() => {
    if (!token) {
      return;
    }
    fetchGeofenceState(token)
      .then((state) => {
        if (!state) return;
        setGeofenceState(state);
      })
      .catch(() => undefined);
  }, [token]);

  useEffect(() => {
    if (!latestMessage) return;

    const deviceId = latestMessage.deviceId;

    if (latestMessage.type === "location_update" && trackingDeviceIds.includes(deviceId)) {
      setLocations((prev) => ({
        ...prev,
        [deviceId]: {
          lat: latestMessage.lat,
          lng: latestMessage.lng,
          insideGeofence: latestMessage.insideGeofence,
          timestamp: latestMessage.timestamp,
        },
      }));
    }

    if (latestMessage.type === "geofence_alert" && trackingDeviceIds.includes(deviceId)) {
      setAlerts((prev) => [
        { ...latestMessage, deviceId },
        ...prev,
      ].slice(0, 10));
      setShowAlerts(true);
    }

    if (latestMessage.type === "geofence_state_update") {
      setGeofenceState(latestMessage);
    }
  }, [latestMessage, trackingDeviceIds]);

  const handleFixedMode = async () => {
    setModeError(null);
    setShareEnabled(false);
    try {
      const state = await postGeofenceMode(token, "fixed");
      setGeofenceState(state);
    } catch (error) {
      setModeError(error instanceof Error ? error.message : "Không thể chuyển về chế độ cố định.");
    }
  };

  const handleMobileMode = async () => {
    setModeError(null);
    if (!isOwner) {
      setModeError("Chỉ chủ thiết bị mới được thay đổi geofence.");
      return;
    }
    try {
      const state = await postGeofenceMode(token, "mobile");
      setGeofenceState(state);
      setShareEnabled(true);
    } catch (error) {
      setModeError(error instanceof Error ? error.message : "Không thể chuyển sang chế độ di động.");
    }
  };

  const validateConfig = (config) => {
    if (!config.name || config.name.trim() === "") {
      return "Tên vùng an toàn không được để trống.";
    }
    if (config.radius < 10 || config.radius > 5000) {
      return "Bán kính phải nằm trong khoảng từ 10m đến 5000m.";
    }
    if (config.mode === 'path' && (!config.path || config.path.length < 2)) {
      return "Vùng an toàn dạng đường đi cần ít nhất 2 điểm.";
    }
    return null;
  };

  const handleSetGeofence = async () => {
    if (!isOwner) return;

    const validationError = validateConfig(pendingConfig);
    if (validationError) {
      setModeError(validationError);
      return;
    }

    try {
      const payload = {
        geofence_id: editingGeofenceId || `gf_${Date.now()}`,
        name: pendingConfig.name || (editingGeofenceId ? currentGeofence.name : "Vùng mới"),
        mode: pendingConfig.mode === 'path' ? 'mobile' : 'fixed',
        radius_m: pendingConfig.radius,
        lat: pendingConfig.mode === 'circle' ? pendingConfig.center?.[0] : null,
        lng: pendingConfig.mode === 'circle' ? pendingConfig.center?.[1] : null,
        path: pendingConfig.mode === 'path' ? pendingConfig.path : null,
      };

      const state = await postGeofenceFull(token, payload);
      setGeofenceState(state);
      setIsPlanMode(false);
      setEditingGeofenceId(null);
      setNewGeofenceName("");
      setModeError(null);
    } catch (error) {
      setModeError(error instanceof Error ? error.message : "Không thể lưu vùng an toàn.");
    }
  };

  const handleDeleteGeofence = async (id) => {
    if (id === "default") {
      setModeError("Không thể xóa vùng an toàn mặc định.");
      return;
    }
    if (!window.confirm("Bạn có chắc chắn muốn xóa vùng an toàn này?")) return;
    try {
      await apiFetch(`${env.backendHttpUrl}/geofence/${id}`, token, { method: "DELETE" });
      const state = await fetchGeofenceState(token);
      setGeofenceState(state);
    } catch (error) {
      setModeError("Không thể xóa vùng an toàn.");
    }
  };

  const toggleDeviceTracking = (deviceId) => {

    setTrackingDeviceIds((prev) => {
      if (prev.includes(deviceId)) {
        return prev.filter((id) => id !== deviceId);
      }
      return [...prev, deviceId];
    });
  };

  const statusClass = useMemo(() => {
    if (status === "connected") return "ok";
    if (status === "connecting") return "warning";
    return "error";
  }, [status]);

  const currentGeofence = useMemo(() => {
    if (!geofenceState.geofences || geofenceState.geofences.length === 0) {
      return {
        mode: "fixed",
        centerLat: env.defaultLat,
        centerLng: env.defaultLng,
        radiusM: env.geofenceRadiusM,
        source: "fixed",
        path: [],
        updatedAt: null,
      };
    }
    // Find the 'default' geofence or just take the first one
    return geofenceState.geofences.find(g => g.id === "default") || geofenceState.geofences[0];
  }, [geofenceState]);

  const center = [
    currentGeofence.centerLat ?? env.defaultLat,
    currentGeofence.centerLng ?? env.defaultLng,
  ];
  const alertCount = alerts.length;

  const trackingDevices = trackingDeviceIds.map((id) => ({
    id,
    ...locations[id],
    color: getDeviceColor(id),
    role: allDevices.find((d) => d.deviceId === id)?.role || "unknown",
  })).filter(d => d.lat !== undefined);

  const handleDeviceSelected = (deviceId) => {
    setFocusedDeviceId(deviceId);
    setShowDeviceList(false);
  };

  const handleClearFocus = () => {
    setFocusedDeviceId(null);
  };

  if (!token) {
    return (
      <section className="full-screen-map">
        <div className="empty-overlay">
          <h3>Vui lòng đăng nhập</h3>
          <p className="muted">Hãy đăng nhập để theo dõi thiết bị.</p>
        </div>
      </section>
    );
  }

  if (allDevices.length === 0) {
    return (
      <section className="full-screen-map">
        <div className="empty-overlay">
          <h3>Chưa có thiết bị</h3>
          <p className="muted">Hãy đăng nhập và thêm thiết bị trong trang Hồ sơ.</p>
        </div>
      </section>
    );
  }

  return (
    <section className={`dashboard-layout${isPlanMode ? " editor-open" : ""}`}>
      <div className={`map-area${isPlanMode ? " editor-open" : ""}`}>
      {/* Top-left: WS Status */}
      <div className="floating-panel top-left">
        <div className={`badge ${statusClass}`}>WS: {status}</div>
      </div>

      {/* Top-right: Device Selector Button */}
      <div className="floating-panel top-right">
        <button
          className="device-selector-btn"
          onClick={() => setShowDeviceList(!showDeviceList)}
          type="button"
        >
          <span className="device-icon">📍</span>
          <span className="device-count">{trackingDeviceIds.length} thiết bị</span>
        </button>
      </div>

      {/* Device List Panel */}
      {showDeviceList && (
        <div className="device-list-panel">
          <div className="device-list-header">
            <h4>Thiết bị đang theo dõi</h4>
            <button
              className="close-btn"
              onClick={() => setShowDeviceList(false)}
              type="button"
            >
              ✕
            </button>
          </div>
          <div className="device-list-content">
            {allDevices.map((device) => {
              const isTracking = trackingDeviceIds.includes(device.deviceId);
              const location = locations[device.deviceId];
              const colors = getDeviceColor(device.deviceId);

              return (
                <div
                  key={device.deviceId}
                  className={`device-item ${isTracking ? "tracking" : ""}`}
                  onClick={() => toggleDeviceTracking(device.deviceId)}
                >
                  <div className="device-info">
                    <div className="device-name">
                      <span
                        className="device-dot"
                        style={{ backgroundColor: colors.primary }}
                      />
                      {device.deviceId}
                    </div>
                    {location && (
                      <div className="device-location">
                        {location.lat?.toFixed(4)}, {location.lng?.toFixed(4)}
                      </div>
                    )}
                  </div>
                  <div className={`toggle ${isTracking ? "on" : "off"}`}>
                    {isTracking ? "Đang theo dõi" : "Tạm dừng"}
                  </div>
                </div>
              );
            })}
          </div>
        </div>
      )}

      {/* Left side: Geofence Status */}
      <div className="floating-panel left-side">
        <h4>Vùng an toàn</h4>
        <div className="geofence-list">
          {geofenceState.geofences?.map((gf) => (
            <div
              key={gf.id}
              className={`geofence-item ${editingGeofenceId === gf.id ? 'editing' : ''}`}
              onClick={() => {
                setEditingGeofenceId(gf.id);
                setNewGeofenceName(gf.name);
                setPendingConfig({
                  name: gf.name,
                  mode: gf.mode === 'fixed' ? 'circle' : 'path',
                  radius: gf.radius_m || 100,
                  center: gf.mode === 'fixed' ? [gf.centerLat, gf.centerLng] : null,
                  path: gf.mode === 'mobile' ? gf.path : [],
                });
                setIsPlanMode(true);
              }}
            >
              <div className="geofence-info">
                <span className="geofence-name">{gf.name}</span>
                <span className="geofence-mode">{gf.mode === 'fixed' ? '📍' : '🛣️'}</span>
              </div>
              {gf.id !== 'default' && (
                <button
                  className="delete-gf-btn"
                  onClick={(e) => {
                    e.stopPropagation();
                    handleDeleteGeofence(gf.id);
                  }}
                >
                  ✕
                </button>
              )}
            </div>
          ))}
          <button
            className="add-geofence-btn"
            onClick={() => {
              setEditingGeofenceId(null);
              setNewGeofenceName("");
              setPendingConfig({
                name: "",
                mode: "circle",
                radius: 100,
                center: null,
                path: [],
              });
              setIsPlanMode(true);
            }}
          >
            + Thêm vùng mới
          </button>
        </div>

        {trackingDevices.length > 0 && (
          <div className="tracking-section">
            <div className="tracking-summary">
              {trackingDevices.map((device) => (
                <div
                  key={device.id}
                  className={`tracking-device ${focusedDeviceId === device.id ? "focused" : ""}`}
                  style={{ borderColor: device.color.primary }}
                  onClick={() => handleDeviceSelected(device.id)}
                >
                  <span
                    className="tracking-dot"
                    style={{ backgroundColor: device.color.primary }}
                  />
                  <span className="tracking-name">{device.id}</span>
                  <span className={device.insideGeofence ? "inside" : "outside"}>
                    {device.insideGeofence ? "✓" : "⚠"}
                  </span>
                  <button
                    className="tracking-toggle-btn"
                    onClick={(e) => {
                      e.stopPropagation();
                      toggleDeviceTracking(device.id);
                    }}
                    type="button"
                  >
                    {trackingDeviceIds.includes(device.id) ? "Tắt" : "Bật"}
                  </button>
                </div>
              ))}
            </div>
            {focusedDeviceId && (
              <button className="clear-focus-btn" onClick={handleClearFocus} type="button">
                Bỏ chọn
              </button>
            )}
            <div className="status-details">
              <p>
                <strong>Bán kính:</strong> {currentGeofence.radiusM} m
              </p>
              <p>
                <strong>Chế độ:</strong> {currentGeofence.mode}
              </p>
            </div>
          </div>
        )}
      </div>

      {/* Right side: Control Buttons */}
      <div className="floating-panel right-side">
        <h4>Điều khiển vùng an toàn</h4>
        <div className="control-buttons">
          <button
            className={`control-btn ${isPlanMode ? "active" : "primary"}`}
            onClick={() => setIsPlanMode(!isPlanMode)}
            type="button"
          >
            {isPlanMode ? "✕ Thoát thiết lập" : "📍 Thiết lập vùng"}
          </button>
          <button
            className="control-btn primary"
            onClick={handleFixedMode}
            type="button"
            disabled={!isOwner}
          >
            Chế độ cố định
          </button>
          <button
            className="control-btn secondary"
            onClick={handleMobileMode}
            type="button"
            disabled={!isOwner}
          >
            Dùng điện thoại này
          </button>
        </div>
        <div className="control-status">
          <span className={`chip ${sharingStatus}`}>
            Chia sẻ: {sharingStatus}
          </span>
          {modeError && <span className="error-text">{modeError}</span>}
        </div>
      </div>

      {/* Top-right corner: Alerts */}
      <div className="floating-panel alerts-trigger">
        <button
          className="alerts-btn"
          onClick={() => setShowAlerts(!showAlerts)}
          type="button"
        >
          <span className="alerts-icon">⚠️</span>
          {alertCount > 0 && (
            <span className="alerts-badge">{alertCount}</span>
          )}
        </button>
      </div>

      {/* Alerts Drawer */}
      {showAlerts && (
        <div className="alerts-drawer">
          <div className="alerts-header">
            <h4>Cảnh báo gần đây</h4>
            <button
              className="close-btn"
              onClick={() => setShowAlerts(false)}
              type="button"
            >
              ✕
            </button>
          </div>
          {alertCount === 0 ? (
            <p className="muted">Chưa có cảnh báo.</p>
          ) : (
            <ul className="alerts-list">
              {alerts.map((item, index) => (
                <li key={`${item.timestamp}-${index}`} className="alert-item">
                  <span className="alert-device">{item.deviceId}</span>
                  <span className="alert-event">{item.event}</span>
                  <span className="alert-loc">
                    ({item.lat?.toFixed(4)}, {item.lng?.toFixed(4)})
                  </span>
                  <span className="alert-time">{formatEpoch(item.timestamp)}</span>
                </li>
              ))}
            </ul>
          )}
        </div>
      )}

      {/* Map - fills remaining space */}
      <div className="map-container">
        <TrackingMap
          center={center}
          locations={locations}
          trackingDeviceIds={trackingDeviceIds}
          geofences={geofenceState.geofences || []}
          onDeviceSelected={handleDeviceSelected}
          pendingConfig={pendingConfig}
        onUpdatePendingConfig={updatePendingConfig}
          isPlanMode={isPlanMode}
          editingGeofenceId={editingGeofenceId}
        />
      </div>

      {/* Right Side Editor Panel */}
      {isPlanMode && (
        <GeofenceEditorPanel
          config={pendingConfig}
          editingGeofence={geofenceState.geofences?.find(g => g.id === editingGeofenceId)}
          onUpdateConfig={updatePendingConfig}
          onSave={handleSetGeofence}
          onCancel={handleCancelPlanMode}
          onRemoveLastPoint={removeLastPoint}
        modeError={modeError}
        />
      )}
    </div>
  </section>
  );
}