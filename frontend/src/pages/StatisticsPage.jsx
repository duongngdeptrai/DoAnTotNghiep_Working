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

ChartJS.register(CategoryScale, LinearScale, BarElement, Title, Tooltip, Legend);

delete L.Icon.Default.prototype._getIconUrl;
L.Icon.Default.mergeOptions({
	iconRetinaUrl: "https://unpkg.com/leaflet@1.9.4/dist/images/marker-icon-2x.png",
	iconUrl: "https://unpkg.com/leaflet@1.9.4/dist/images/marker-icon.png",
	shadowUrl: "https://unpkg.com/leaflet@1.9.4/dist/images/marker-shadow.png",
});

function formatDistance(meters) {
	if (!meters) return "0 m";
	if (meters >= 1000) return `${(meters / 1000).toFixed(2)} km`;
	return `${Math.round(meters)} m`;
}

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
					pathOptions={{ color: "#22d3ee", weight: 5, opacity: 0.9 }}
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

const RANGE_LABELS = { "24h": "24 giờ", "7d": "7 ngày", "30d": "30 ngày", all: "Tất cả" };

export default function StatisticsPage({ devices, selectedDeviceId, onSelectDevice }) {
	const { device_id } = useParams();
	const [stats, setStats] = useState(null);
	const [dailyStats, setDailyStats] = useState([]);
	const [trackPath, setTrackPath] = useState([]);
	const [loading, setLoading] = useState(true);
	const [error, setError] = useState(null);
	const [range, setRange] = useState("24h");

	const deviceParam = device_id || selectedDeviceId;
	const deviceList = devices?.map((d) => d.deviceId) || [];

	useEffect(() => {
		if (!deviceParam) {
			setLoading(false);
			return;
		}

		const now = Math.floor(Date.now() / 1000);
		let start = null;
		let interval = "day";

		switch (range) {
			case "24h": start = now - 24 * 3600; interval = "hour"; break;
			case "7d": start = now - 7 * 24 * 3600; interval = "day"; break;
			case "30d": start = now - 30 * 24 * 3600; interval = "week"; break;
			case "all": start = now - 365 * 24 * 3600; interval = "year"; break;
		}

		const loadStats = async () => {
			setLoading(true);
			setError(null);
			try {
				const [statsRes, dailyRes] = await Promise.all([
					fetchStatistics(deviceParam, start, now),
					fetchAggregatedStats(deviceParam, start, now, interval),
				]);
				setStats(statsRes);
				setTrackPath(statsRes.trackPath || []);
				setDailyStats(dailyRes);
			} catch (err) {
				setError(err instanceof Error ? err.message : "Không thể tải thống kê");
			} finally {
				setLoading(false);
			}
		};

		loadStats();
	}, [deviceParam, range]);

	const chartData = useMemo(() => ({
		labels: dailyStats.map((d) => d.label),
		datasets: [
			{
				label: "Quãng đường (km)",
				data: dailyStats.map((d) => d.totalDistanceM / 1000),
				backgroundColor: "rgba(34, 211, 238, 0.25)",
				borderColor: "#22d3ee",
				borderWidth: 2,
				borderRadius: 6,
				borderSkipped: false,
			},
		],
	}), [dailyStats]);

	if (devices?.length === 0) {
		return (
			<div className="page statistics-page">
				<div className="empty-state">
					<div className="empty-icon">📊</div>
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
					<div className="empty-icon">⚠️</div>
					<h3>Không thể tải thống kê</h3>
					<p>{error}</p>
				</div>
			</div>
		);
	}

	return (
		<div className="page statistics-page">
			<div className="page-header">
				<div>
					<h1>Thống kê</h1>
					<p className="muted">Lịch sử di chuyển và phân tích dữ liệu</p>
				</div>
				{deviceList.length > 0 && (
					<div className="device-selector">
						<label>Thiết bị</label>
						<select
							value={deviceParam || ""}
							onChange={(e) => onSelectDevice?.(e.target.value)}
						>
							{deviceList.map((id) => (
								<option key={id} value={id}>{id}</option>
							))}
						</select>
					</div>
				)}
			</div>

			<div className="date-range-selector">
				{Object.entries(RANGE_LABELS).map(([r, label]) => (
					<button
						key={r}
						className={`range-btn${range === r ? " active" : ""}`}
						onClick={() => setRange(r)}
					>
						{label}
					</button>
				))}
			</div>

			{!stats ? (
				<div className="empty-state">
					<div className="empty-icon">📭</div>
					<h3>Không có dữ liệu</h3>
					<p>Thiết bị chưa có dữ liệu vị trí trong khoảng thời gian này.</p>
				</div>
			) : (
				<>
					<div className="stats-grid">
						<div className="stat-card accent">
							<span className="stat-icon">🛣️</span>
							<div className="stat-info">
								<div className="stat-label">Tổng quãng đường</div>
								<div className="stat-value">{formatDistance(stats.totalDistanceM)}</div>
							</div>
						</div>
						<div className="stat-card">
							<span className="stat-icon">📍</span>
							<div className="stat-info">
								<div className="stat-label">Số điểm vị trí</div>
								<div className="stat-value">{stats.pointCount ?? 0}</div>
							</div>
						</div>
						<div className="stat-card">
							<span className="stat-icon">⚡</span>
							<div className="stat-info">
								<div className="stat-label">Tốc độ trung bình</div>
								<div className="stat-value">
									{stats.avgSpeedKmh?.toFixed(1) || "0"}
									<span className="stat-unit"> km/h</span>
								</div>
							</div>
						</div>
						<div className="stat-card">
							<span className="stat-icon">🚀</span>
							<div className="stat-info">
								<div className="stat-label">Tốc độ tối đa</div>
								<div className="stat-value">
									{stats.maxSpeedKmh?.toFixed(1) || "0"}
									<span className="stat-unit"> km/h</span>
								</div>
							</div>
						</div>
					</div>

					<div className="stats-sections">
						<div className="stats-section chart-section">
							<h3>Quãng đường theo thời gian</h3>
							{dailyStats.length === 0 ? (
								<div className="empty-chart">
									<p>Chưa có dữ liệu cho khoảng thời gian này.</p>
								</div>
							) : (
								<div className="chart-container">
									<Bar data={chartData} options={chartOptions} />
								</div>
							)}
						</div>

						{trackPath.length > 0 && (
							<div className="stats-section full-map">
								<h3>Lộ trình di chuyển</h3>
								<TrackMap trackPath={trackPath} />
							</div>
						)}
					</div>
				</>
			)}
		</div>
	);
}

const chartOptions = {
	responsive: true,
	maintainAspectRatio: false,
	plugins: {
		legend: { display: false },
		title: { display: false },
		tooltip: {
			backgroundColor: "rgba(15, 23, 42, 0.95)",
			titleColor: "#e2e8f0",
			bodyColor: "#9aa4b2",
			borderColor: "rgba(255, 255, 255, 0.14)",
			borderWidth: 1,
			padding: 12,
			callbacks: {
				label: (ctx) => ` ${ctx.parsed.y.toFixed(2)} km`,
			},
		},
	},
	scales: {
		x: {
			grid: { color: "rgba(255, 255, 255, 0.06)" },
			border: { color: "rgba(255, 255, 255, 0.1)" },
			ticks: {
				color: "#9aa4b2",
				font: { family: "Space Grotesk", size: 12 },
				maxRotation: 45,
			},
		},
		y: {
			beginAtZero: true,
			grid: { color: "rgba(255, 255, 255, 0.06)" },
			border: { color: "rgba(255, 255, 255, 0.1)" },
			ticks: {
				color: "#9aa4b2",
				font: { family: "Space Grotesk", size: 12 },
				callback: (value) => value + " km",
			},
		},
	},
};
