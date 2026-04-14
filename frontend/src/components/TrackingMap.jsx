import { Circle, MapContainer, Marker, Popup, TileLayer } from "react-leaflet";
import "leaflet/dist/leaflet.css";
import L from "leaflet";

const markerIcon = L.icon({
  iconUrl: "https://unpkg.com/leaflet@1.9.4/dist/images/marker-icon.png",
  shadowUrl: "https://unpkg.com/leaflet@1.9.4/dist/images/marker-shadow.png",
  iconSize: [25, 41],
  iconAnchor: [12, 41],
});

export default function TrackingMap({ center, markerPosition, geofenceRadiusM }) {
  return (
    <MapContainer center={center} zoom={16} style={{ height: "100%", width: "100%" }}>
      <TileLayer
        attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors'
        url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
      />

      <Circle
        center={center}
        radius={geofenceRadiusM}
        pathOptions={{ color: "#0077cc", fillColor: "#6ec6ff", fillOpacity: 0.25 }}
      />

      <Marker position={markerPosition} icon={markerIcon}>
        <Popup>Tracked device</Popup>
      </Marker>
    </MapContainer>
  );
}
