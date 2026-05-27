import { Circle, CircleMarker, MapContainer, Marker, Popup, Polyline, TileLayer, useMap, useMapEvent, Polygon } from "react-leaflet";
import React, { useEffect, useMemo, useState } from "react";
import "leaflet/dist/leaflet.css";
import L from "leaflet";

const markerIcon = L.icon({
  iconUrl: "https://unpkg.com/leaflet@1.9.4/dist/images/marker-icon.png",
  shadowUrl: "https://unpkg.com/leaflet@1.9.4/dist/images/marker-shadow.png",
  iconSize: [25, 41],
  iconAnchor: [12, 41],
});

function MapSync({ center, locations, trackingDeviceIds, selectedDeviceId }) {
  const map = useMap();

  useEffect(() => {
    if (selectedDeviceId && locations[selectedDeviceId]) {
      const loc = locations[selectedDeviceId];
      map.setView([loc.lat, loc.lng], 17, { animate: true });
      return;
    }

    if (trackingDeviceIds.length === 0) {
      map.setView(center, map.getZoom(), { animate: true });
      return;
    }

    const coords = trackingDeviceIds
      .map((id) => locations[id])
      .filter((loc) => loc && loc.lat && loc.lng)
      .map((loc) => [loc.lat, loc.lng]);

    if (coords.length > 0) {
      if (coords.length === 1) {
        map.setView(coords[0], map.getZoom(), { animate: true });
      } else {
        const bounds = L.latLngBounds(coords);
        map.fitBounds(bounds, { padding: [50, 50], animate: true });
      }
    } else {
      map.setView(center, map.getZoom(), { animate: true });
    }
  }, [center, locations, trackingDeviceIds, selectedDeviceId, map]);

  return null;
}

function MapClickHandler({ onDeviceFound, onMapClick, locations, trackingDeviceIds, isPlanMode }) {
  useMapEvent({
    click(e) {
      const clickedLat = e.latlng.lat;
      const clickedLng = e.latlng.lng;

      if (isPlanMode) {
        onMapClick(clickedLat, clickedLng);
        return;
      }

      let nearestDevice = null;
      let nearestDistance = Infinity;

      trackingDeviceIds.forEach((deviceId) => {
        const loc = locations[deviceId];
        if (!loc || !loc.lat || !loc.lng) return;

        const distance = Math.sqrt(
          Math.pow(loc.lat - clickedLat, 2) + Math.pow(loc.lng - clickedLng, 2)
        );

        if (distance < nearestDistance) {
          nearestDistance = distance;
          nearestDevice = { deviceId, location: loc };
        }
      });

      if (nearestDevice && nearestDistance < 0.02) {
        onDeviceFound(nearestDevice.deviceId, nearestDevice.location);
      } else {
        onMapClick(clickedLat, clickedLng);
      }
    },
  });

  return null;
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

function createColoredIcon(color) {
  return L.divIcon({
    className: "custom-marker-icon",
    html: `
      <svg width="25" height="41" viewBox="0 0 25 41" fill="none" xmlns="http://www.w3.org/2000/svg">
        <path d="M12.5 0C5.6 0 0 5.6 0 12.5C0 22 12.5 41 12.5 41C12.5 41 25 22 25 12.5C25 5.6 19.4 0 12.5 0Z" fill="${color}"/>
        <circle cx="12.5" cy="12.5" r="6" fill="white"/>
      </svg>
    `,
    iconSize: [25, 41],
    iconAnchor: [12, 41],
    popupAnchor: [0, -15],
  });
}

function createSelectedIcon(color) {
  return L.divIcon({
    className: "custom-marker-icon selected",
    html: `
      <svg width="35" height="55" viewBox="0 0 35 55" fill="none" xmlns="http://www.w3.org/2000/svg">
        <circle cx="17.5" cy="17.5" r="15" fill="${color}" opacity="0.3"/>
        <circle cx="17.5" cy="17.5" r="10" fill="${color}" opacity="0.5"/>
        <path d="M17.5 0C10.6 0 5 5.6 5 12.5C5 25 17.5 55 17.5 55C17.5 55 30 25 30 12.5C30 5.6 24.4 0 17.5 0Z" fill="${color}"/>
        <circle cx="17.5" cy="12.5" r="8" fill="white"/>
      </svg>
    `,
    iconSize: [35, 55],
    iconAnchor: [17, 50],
    popupAnchor: [0, -20],
  });
}

export default function TrackingMap({
  center,
  locations,
  trackingDeviceIds = [],
  geofences = [],
  onDeviceSelected,
  onSetGeofence,
  isPlanMode,
  editingGeofenceId,
  onSaveGeofenceName,
}) {
  const [selectedDevice, setSelectedDevice] = useState(null);
  const [pendingCenter, setPendingCenter] = useState(null);
  const [pendingPath, setPendingPath] = useState([]);
  const [drawMode, setDrawMode] = useState('circle');

  // Use the currently editing geofence's radius or default
  const editingGeofence = geofences.find(g => g.id === editingGeofenceId);
  const [pendingRadius, setPendingRadius] = useState(editingGeofence?.radiusM || 100);

  useEffect(() => {
    setPendingRadius(editingGeofence?.radiusM || 100);
  }, [editingGeofence]);

  const handleDeviceFound = (deviceId, location) => {
    setSelectedDevice({ deviceId, location });
    if (onDeviceSelected) {
      onDeviceSelected(deviceId);
    }
  };

  const handleClearSelection = () => {
    setSelectedDevice(null);
    if (onDeviceSelected) {
      onDeviceSelected(null);
    }
  };

  const handleMapClick = (lat, lng) => {
    if (drawMode === 'path') {
      setPendingPath((prev) => [...prev, [lat, lng]]);
    } else {
      setPendingCenter([lat, lng]);
      setSelectedDevice(null);
    }
  };

  const handleSaveGeofence = () => {
    if (drawMode === 'path') {
      if (pendingPath.length < 2) {
        alert("Vui lòng chọn ít nhất 2 điểm để tạo đường đi.");
        return;
      }
      if (onSetGeofence) {
        onSetGeofence({
          type: 'path',
          path: pendingPath,
          radius: pendingRadius
        });
        setPendingPath([]);
      }
    } else {
      if (pendingCenter && onSetGeofence) {
        onSetGeofence({
          type: 'circle',
          center: pendingCenter,
          radius: pendingRadius
        });
        setPendingCenter(null);
      }
    }
  };

  const safeRadius = (pendingRadius && !isNaN(pendingRadius)) ? pendingRadius : 100;

  const calculateCapsulePolygon = (path, radiusM) => {
    if (!path || path.length < 2) return null;

    const actualRadius = (radiusM && !isNaN(radiusM)) ? radiusM : 100;
    const R = actualRadius / 111320;
    const points = [];

    // 1. Biên trái: đi từ điểm đầu đến điểm cuối
    for (let i = 0; i < path.length - 1; i++) {
      const p1 = path[i];
      const p2 = path[i + 1];
      const dx = p2[0] - p1[0];
      const dy = p2[1] - p1[1];
      const len = Math.sqrt(dx * dx + dy * dy);
      const nx = -dy / len * R;
      const ny = dx / len * R;

      if (i === 0) {
        points.push([p1[0] + nx, p1[1] + ny]);
      }
      points.push([p2[0] + nx, p2[1] + ny]);
    }

    // 2. Biên phải: đi ngược từ điểm cuối về điểm đầu
    for (let i = path.length - 1; i >= 0; i--) {
      if (i === path.length - 1) {
        const pPenultimate = path[path.length - 2];
        const dx = path[i][0] - pPenultimate[0];
        const dy = path[i][1] - pPenultimate[1];
        const len = Math.sqrt(dx * dx + dy * dy);
        const nx = -dy / len * R;
        const ny = dx / len * R;
        points.push([path[i][0] - nx, path[i][1] - ny]);
      } else {
        const p1 = path[i];
        const p2 = path[i + 1];
        const dx = p2[0] - p1[0];
        const dy = p2[1] - p1[1];
        const len = Math.sqrt(dx * dx + dy * dy);
        const nx = -dy / len * R;
        const ny = dx / len * R;
        points.push([p1[0] - nx, p1[1] - ny]);
      }
    }

    return points;
  };

  const deviceMarkers = useMemo(() => {
    return trackingDeviceIds.map((deviceId) => {
      const location = locations[deviceId];
      if (!location || !location.lat || !location.lng) return null;

      const is_selected = selectedDevice?.deviceId === deviceId;
      const colors = getDeviceColor(deviceId);
      const icon = is_selected ? createSelectedIcon(colors.primary) : createColoredIcon(colors.primary);

      return (
        <Marker
          key={deviceId}
          position={[location.lat, location.lng]}
          icon={icon}
        >
          <Popup>
            <div style={{ minWidth: "100px" }}>
              <strong>{deviceId}</strong>
              {is_selected && <span> (Đã chọn)</span>}
              <br />
              <small>
                {location.insideGeofence ? "✓ Trong vùng an toàn" : "⚠ Ngoài vùng an toàn"}
              </small>
              <br />
              <small style={{ color: "#666" }}>
                {location.lat.toFixed(6)}, {location.lng.toFixed(6)}
              </small>
            </div>
          </Popup>
        </Marker>
      );
    }).filter(Boolean);
  }, [locations, trackingDeviceIds, selectedDevice]);

  const polylinePoints = useMemo(() => {
    if (trackingDeviceIds.length < 2) return null;

    const points = trackingDeviceIds
      .map((id) => locations[id])
      .filter((loc) => loc && loc.lat && loc.lng)
      .map((loc) => [loc.lat, loc.lng]);

    return points.length >= 2 ? points : null;
  }, [locations, trackingDeviceIds]);

  if (!center || !center[0] || !center[1]) {
    return <div style={{ height: "100%", width: "100%", display: "flex", alignItems: "center", justifyContent: "center" }}>Đang tải bản đồ...</div>;
  }

  return (
    <div style={{ position: 'relative', height: '100%', width: '100%' }}>
      {(pendingCenter || pendingPath.length > 0) && (
        <div style={styles.panel}>
          <div style={styles.header}>
            <span style={styles.icon}>{drawMode === 'path' ? '🛣️' : '📍'}</span>
            <strong>Thiết lập vùng an toàn</strong>
          </div>

          <div style={styles.modeSelector}>
            <button
              onClick={() => { setDrawMode('circle'); setPendingPath([]); setPendingCenter(null); }}
              style={{ ...styles.modeBtn, backgroundColor: drawMode === 'circle' ? '#3b82f6' : '#f1f5f9', color: drawMode === 'circle' ? 'white' : '#64748b' }}
            >
              Hình tròn
            </button>
            <button
              onClick={() => { setDrawMode('path'); setPendingCenter(null); }}
              style={{ ...styles.modeBtn, backgroundColor: drawMode === 'path' ? '#3b82f6' : '#f1f5f9', color: drawMode === 'path' ? 'white' : '#64748b' }}
            >
              Đường đi
            </button>
          </div>

          <div style={styles.inputGroup}>
            <label style={styles.label}>Bán kính vùng an toàn (mét)</label>
            <div style={styles.inputWrapper}>
              <input
                type="number"
                value={pendingRadius}
                onChange={(e) => setPendingRadius(Number(e.target.value))}
                style={styles.input}
                placeholder="Nhập bán kính..."
              />
              <span style={styles.unit}>m</span>
            </div>
          </div>
          <div style={styles.buttonGroup}>
            <button onClick={handleSaveGeofence} style={styles.saveButton}>
              Lưu thay đổi
            </button>
            <button
              onClick={() => { setPendingCenter(null); setPendingPath([]); }}
              style={styles.cancelButton}
            >
              Hủy bỏ
            </button>
          </div>
        </div>
      )}
      <MapContainer center={center} zoom={16} style={{ height: "100%", width: "100%" }} zoomControl={false}>
        <MapSync center={center} locations={locations} trackingDeviceIds={trackingDeviceIds} selectedDeviceId={selectedDevice?.deviceId} />
        <MapClickHandler
          onDeviceFound={handleDeviceFound}
          onMapClick={handleMapClick}
          locations={locations}
          trackingDeviceIds={trackingDeviceIds}
          isPlanMode={isPlanMode}
        />
        <TileLayer
          attribution='&copy; <a href="https://openstreetmap.org/copyright">OpenStreetMap</a> contributors'
          url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
        />

        {/* Render All Geofences */}
        {geofences.map((gf) => (
          <React.Fragment key={gf.id}>
            {gf.mode === 'fixed' && (
              <Circle
                center={[gf.centerLat, gf.centerLng]}
                radius={gf.radiusM}
                pathOptions={{
                  color: editingGeofenceId === gf.id ? "#f97316" : "#3b82f6",
                  fillColor: editingGeofenceId === gf.id ? "#f97316" : "#3b82f6",
                  fillOpacity: 0.15,
                  weight: editingGeofenceId === gf.id ? 3 : 1
                }}
              />
            )}
            {gf.mode === 'mobile' && gf.path && gf.path.length >= 2 && (
              <Polygon
                positions={calculateCapsulePolygon(gf.path, gf.radiusM)}
                pathOptions={{
                  color: editingGeofenceId === gf.id ? "#f97316" : "#3b82f6",
                  fillColor: editingGeofenceId === gf.id ? "#f97316" : "#3b82f6",
                  fillOpacity: 0.15,
                  weight: editingGeofenceId === gf.id ? 3 : 2
                }}
              />
            )}
          </React.Fragment>
        ))}

        {/* Render saved geofence path if exists */}
        {/* Removed old single geofence path render */}

        {pendingCenter && drawMode === 'circle' && (
          <Circle
            center={pendingCenter}
            radius={pendingRadius}
            pathOptions={{ color: "#f97316", fillColor: "#f97316", fillOpacity: 0.2, dashArray: "5, 5" }}
          />
        )}
        {pendingPath.length > 0 && (
          <Polyline
            positions={pendingPath}
            pathOptions={{ color: "#f97316", weight: 2, opacity: 0.5 }}
          />
        )}
        {pendingPath.length >= 2 && (
          <Polygon
            positions={calculateCapsulePolygon(pendingPath, pendingRadius)}
            pathOptions={{ color: "#f97316", fillColor: "#f97316", fillOpacity: 0.2, weight: 2, dashArray: "5, 5" }}
          />
        )}
        {pendingPath.length > 0 && pendingPath.map((pos, idx) => (
          <CircleMarker
            key={`path-point-${idx}`}
            center={pos}
            radius={4}
            pathOptions={{ color: "#f97316", fillColor: "#f97316", fillOpacity: 1 }}
          />
        ))}

        <CircleMarker
          center={center}
          radius={10}
          pathOptions={{ color: "#f97316", fillColor: "#fb923c", fillOpacity: 1, weight: 3 }}
        >
          <Popup>Vùng an toàn</Popup>
        </CircleMarker>

        {polylinePoints && (
          <Polyline
            positions={polylinePoints}
            pathOptions={{ color: "#94a3b8", weight: 2, dashArray: "5, 10" }}
          />
        )}

        {deviceMarkers}

        {selectedDevice && (
          <CircleMarker
            center={[selectedDevice.location.lat, selectedDevice.location.lng]}
            radius={20}
            pathOptions={{ color: "#fbbf24", fillColor: "#fbbf24", fillOpacity: 0.3, weight: 3 }}
          >
            <Popup>Thiết bị được chọn: {selectedDevice.deviceId}</Popup>
          </CircleMarker>
        )}
      </MapContainer>
    </div>
  );
}

const styles = {
  panel: {
    position: 'absolute',
    top: '20px',
    left: '50%',
    transform: 'translateX(-50%)',
    zIndex: 9999,
    backgroundColor: '#ffffff',
    padding: '20px',
    borderRadius: '16px',
    boxShadow: '0 10px 25px rgba(0,0,0,0.15)',
    display: 'flex',
    flexDirection: 'column',
    gap: '16px',
    minWidth: '280px',
    fontFamily: '-apple-system, BlinkmacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif',
    border: '1px solid #e2e8f0',
  },
  header: {
    display: 'flex',
    alignItems: 'center',
    gap: '8px',
    fontSize: '16px',
    color: '#1e293b',
    borderBottom: '1px solid #f1f5f9',
    paddingBottom: '12px',
  },
  icon: {
    fontSize: '18px',
  },
  inputGroup: {
    display: 'flex',
    flexDirection: 'column',
    gap: '8px',
  },
  label: {
    fontSize: '13px',
    fontWeight: '500',
    color: '#64748b',
    marginLeft: '2px',
  },
  inputWrapper: {
    position: 'relative',
    display: 'flex',
    alignItems: 'center',
  },
  input: {
    padding: '10px 12px',
    borderRadius: '8px',
    border: '1px solid #cbd5e1',
    fontSize: '15px',
    outline: 'none',
    transition: 'border-color 0.2s',
    boxSizing: 'border-box',
  },
  unit: {
    position: 'absolute',
    right: '12px',
    color: '#94a3b8',
    fontSize: '14px',
    pointerEvents: 'none',
  },
  buttonGroup: {
    display: 'flex',
    gap: '10px',
    marginTop: '4px',
  },
  saveButton: {
    flex: 1,
    padding: '10px',
    backgroundColor: '#3b82f6',
    color: '#ffffff',
    border: 'none',
    borderRadius: '8px',
    cursor: 'pointer',
    fontWeight: '600',
    fontSize: '14px',
    transition: 'background-color 0.2s',
  },
  cancelButton: {
    flex: 1,
    padding: '10px',
    backgroundColor: '#f1f5f9',
    color: '#475569',
    border: 'none',
    borderRadius: '8px',
    cursor: 'pointer',
    fontWeight: '600',
    fontSize: '14px',
    transition: 'background-color 0.2s',
  },
  modeSelector: {
    display: 'flex',
    gap: '8px',
    padding: '4px',
    backgroundColor: '#f1f5f9',
    borderRadius: '10px',
    marginBottom: '8px',
  },
  modeBtn: {
    flex: 1,
    padding: '6px',
    border: 'none',
    borderRadius: '7px',
    cursor: 'pointer',
    fontSize: '13px',
    fontWeight: '500',
    transition: 'all 0.2s',
  },
};
