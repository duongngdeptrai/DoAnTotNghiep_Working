import { useEffect, useState, useMemo } from "react";
import { useParams } from "react-router-dom";
import { MapContainer, TileLayer, Polyline, Marker, Popup } from "react-leaflet";
import { fetchStatistics, fetchAggregatedStats } from "../lib/api";
import "leaflet/dist/leaflet.css";
import L from "leaflet";
import {
  Chart as ChartJS,
  CategoryScale,
  LinearScale,
  BarElement,
  Title,
  Tooltip,
  Legend,
} from "chart.js";
import { Bar } from "react-chartjs-2";

ChartJS.register(
  CategoryScale,
  LinearScale,
  BarElement,
  Title,
  Tooltip,
  Legend
);

// Fix Leaflet default marker icon
delete L.Icon.Default.prototype._getIconUrl;
L.Icon.Default.mergeOptions({
  iconRetinaUrl: "https://unpkg.com/leaflet@1.9.4/dist/images/marker-icon-2x.png",
  iconUrl: "https://unpkg.com/leaflet@1.9.4/dist/images/marker-icon.png",
  shadowUrl: "https://unpkg.com/leaflet@1.9.4/dist/images/marker-shadow.png",
});

function formatDistance(meters) {
  if (!meters) return "0 m";
  if (meters >= 1000) {
    return `${(meters / 1000).toFixed(2)} km`;
  }
  return `${Math.round(meters)} m`;
}

// Simple Track Map Component
function TrackMap({ trackPath }) {
  if (!trackPath || trackPath.length === 0) {
    return (
      <div className="track-map-empty">
        <p>Không có dữ liệu lộ trình.</p>
      </div>
    );
  }

  const points = trackPath.map((p) => [p.lat, p.lng]);
  const startPoint = points[0];
  const endPoint = points[points.length - 1];

  // Calculate bounds to fit all points
  const lats = points.map((p) => p[0]);
  const lngs = points.map((p) => p[1]);
  const bounds = [
    [Math.min(...lats), Math.min(...lngs)],
    [Math.max(...lats), Math.max(...lngs)],
  ];

  return (
    <div className="track-map-container">
      <MapContainer
        center={startPoint}
        zoom={13}
        bounds={bounds}
        style={{ height: "100%", width: "100%" }}
        boundsOptions={{ padding: [50, 50] }}
      >
        <TileLayer
          attribution='&copy; <a href="https://openstreetmap.org/copyright">OpenStreetMap</a> contributors'
          url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
        />
        <Polyline
          positions={points}
          pathOptions={{ color: "#ef4444", weight: 5, opacity: 0.9 }}
        />
        <Marker position={startPoint}>
          <Popup>Điểm bắt đầu</Popup>
        </Marker>
        <Marker position={endPoint}>
          <Popup>Điểm kết thúc</Popup>
        </Marker>
      </MapContainer>
    </div>
  );
}

export default function StatisticsPage({ token, devices, selectedDeviceId, onSelectDevice }) {
  const { device_id } = useParams();
  const [stats, setStats] = useState(null);
  const [dailyStats, setDailyStats] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [range, setRange] = useState("24h"); // '24h' | '7d' | '30d' | 'all'

  const deviceParam = device_id || selectedDeviceId;
  const deviceList = devices?.map((d) => d.deviceId) || [];

  useEffect(() => {
    if (!token || !deviceParam) {
      setLoading(false);
      return;
    }

    const now = Math.floor(Date.now() / 1000);
    let start = null;
    let interval = "day";

    switch (range) {
      case "24h":
        start = now - 24 * 3600;
        interval = "hour";
        break;
      case "7d":
        start = now - 7 * 24 * 3600;
        interval = "day";
        break;
      case "30d":
        start = now - 30 * 24 * 3600;
        interval = "week";
        break;
      case "all":
        start = now - 365 * 24 * 3600; // 1 year
        interval = "year";
        break;
    }
    const end = now;

    const loadStats = async () => {
      setLoading(true);
      setError(null);
      try {
        const [statsRes, dailyRes] = await Promise.all([
          fetchStatistics(token, deviceParam, start, end),
          fetchAggregatedStats(token, deviceParam, start, end, interval),
        ]);
        setStats(statsRes);
        setDailyStats(dailyRes);
      } catch (err) {
        setError(err instanceof Error ? err.message : "Không thể tải thống kê");
      } finally {
        setLoading(false);
      }
    };

    loadStats();
  }, [token, deviceParam, range]);

  const handleDateRangeChange = (newRange) => {
    setRange(newRange);
  };

  const chartData = useMemo(() => {
    const labels = dailyStats.map((d) => d.label);
    const distances = dailyStats.map((d) => d.totalDistanceM / 1000); // Convert to km

    return {
      labels,
      datasets: [
        {
          label: "Quãng đường (km)",
          data: distances,
          backgroundColor: "rgba(34, 211, 238, 0.6)",
          borderColor: "rgb(34, 211, 238)",
          borderWidth: 1,
        },
      ],
    };
  }, [dailyStats]);

  if (!token) {
    return (
      <div className="page statistics-page">
        <div className="empty-state">
          <h3>Vui lòng đăng nhập</h3>
        </div>
      </div>
    );
  }

  if (devices?.length === 0) {
    return (
      <div className="page statistics-page">
        <div className="empty-state">
          <h3>Chưa có thiết bị</h3>
          <p>Hãy đăng ký thiết bị để xem thống kê.</p>
        </div>
      </div>
    );
  }

  if (loading) {
    return (
      <div className="page statistics-page">
        <div className="loading-container">
          <div className="spinner" />
          <p>Đang tải thống kê...</p>
        </div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="page statistics-page">
        <div className="error-state">
          <h3>Lỗi</h3>
          <p>{error}</p>
        </div>
      </div>
    );
  }

  return (
    <div className="page statistics-page">
      <div className="page-header">
        <h1>Thống kê</h1>
        <div className="device-selector">
          <label>Thiết bị: </label>
          <select
            value={deviceParam || ""}
            onChange={(e) => {
              const value = e.target.value;
              if (onSelectDevice) {
                onSelectDevice(value);
              } else {
                window.location.hash = `/stats/${value}`;
              }
            }}
          >
            {deviceList.map((id) => (
              <option key={id} value={id}>
                {id}
              </option>
            ))}
          </select>
        </div>
      </div>

      <div className="date-range-selector">
        <button
          className={`range-btn ${range === "24h" ? "active" : ""}`}
          onClick={() => handleDateRangeChange("24h")}
          type="button"
        >
          24h
        </button>
        <button
          className={`range-btn ${range === "7d" ? "active" : ""}`}
          onClick={() => handleDateRangeChange("7d")}
          type="button"
        >
          7 ngày
        </button>
        <button
          className={`range-btn ${range === "30d" ? "active" : ""}`}
          onClick={() => handleDateRangeChange("30d")}
          type="button"
        >
          30 ngày
        </button>
        <button
          className={`range-btn ${range === "all" ? "active" : ""}`}
          onClick={() => handleDateRangeChange("all")}
          type="button"
        >
          Tất cả
        </button>
      </div>

      <div className="stats-grid">
        <div className="stat-card">
          <div className="stat-icon">📍</div>
          <div className="stat-info">
            <div className="stat-label">Tổng điểm</div>
            <div className="stat-value">{stats?.totalPoints?.toLocaleString() || "0"}</div>
          </div>
        </div>
        <div className="stat-card accent">
          <div className="stat-icon">🛣️</div>
          <div className="stat-info">
            <div className="stat-label">Tổng quãng đường</div>
            <div className="stat-value">{formatDistance(stats?.totalDistanceM)}</div>
          </div>
        </div>
      </div>

      <div className="stats-sections">
        <section className="stats-section chart-section">
          <h3>📈 Quãng đường theo ngày</h3>
          {dailyStats.length > 0 ? (
            <div className="chart-container">
              <Bar
                data={chartData}
                options={{
                  responsive: true,
                  maintainAspectRatio: false,
                  plugins: {
                    legend: {
                      display: false,
                    },
                    title: {
                      display: false,
                    },
                  },
                  scales: {
                    y: {
                      beginAtZero: true,
                      title: {
                        display: true,
                        text: "km",
                      },
                    },
                  },
                }}
              />
            </div>
          ) : (
            <div className="empty-chart">
              <p>Không có dữ liệu để hiển thị biểu đồ.</p>
            </div>
          )}
        </section>

        <section className="stats-section full-map">
          <h3>🛤️ Lộ trình di chuyển</h3>
          {stats?.trackPath?.length === 0 ? (
            <div className="empty-map">
              <p>Không có dữ liệu đường đi.</p>
            </div>
          ) : (
            <TrackMap key={`${deviceParam}-${range}`} trackPath={stats.trackPath} />
          )}
        </section>
      </div>
    </div>
  );
}
