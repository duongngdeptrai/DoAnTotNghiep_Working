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
  isPlanMode,
  editingGeofenceId,
  pendingConfig = { mode: 'circle', radius: 100, center: null, path: [] },
  onUpdatePendingConfig,
}) {
  const [selectedDevice, setSelectedDevice] = useState(null);

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
    if (!isPlanMode) return;

    if (pendingConfig.mode === 'path') {
      onUpdatePendingConfig({
        path: [...(pendingConfig.path || []), [lat, lng]]
      });
    } else {
      onUpdatePendingConfig({
        center: [lat, lng]
      });
      setSelectedDevice(null);
    }
  };

  const calculateCapsulePolygon = (path, radiusM) => {
    if (!path || path.length < 2) return null;

    const actualRadius = (radiusM && !isNaN(radiusM)) ? radiusM : 100;
    const R = actualRadius / 111320;
    const points = [];

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

        {/* Render pending geofence visualization */}
        {pendingConfig?.mode === 'circle' && pendingConfig?.center && (
          <Circle
            center={pendingConfig.center}
            radius={pendingConfig.radius}
            pathOptions={{ color: "#f97316", fillColor: "#f97316", fillOpacity: 0.2, dashArray: "5, 5" }}
          />
        )}
        {pendingConfig?.mode === 'path' && pendingConfig?.path?.length > 0 && (
          <Polyline
            positions={pendingConfig.path}
            pathOptions={{ color: "#f97316", weight: 2, opacity: 0.5 }}
          />
        )}
        {pendingConfig?.mode === 'path' && pendingConfig?.path?.length >= 2 && (
          <Polygon
            positions={calculateCapsulePolygon(pendingConfig.path, pendingConfig.radius)}
            pathOptions={{ color: "#f97316", fillColor: "#f97316", fillOpacity: 0.2, weight: 2, dashArray: "5, 5" }}
          />
        )}
        {pendingConfig?.mode === 'path' && pendingConfig?.path?.length > 0 && pendingConfig.path.map((pos, idx) => (
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
