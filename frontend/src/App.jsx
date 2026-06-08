import { useEffect, useState } from "react";
import { BrowserRouter, Navigate, Route, Routes } from "react-router-dom";
import { env } from "./config/env";
import TopNav from "./components/TopNav";
import AuthPage from "./pages/AuthPage";
import DashboardPage from "./pages/DashboardPage";
import ProfilePage from "./pages/ProfilePage";
import StatisticsPage from "./pages/StatisticsPage";
import {
  authLogin,
  authRegister,
  fetchDevices,
  registerDevice,
} from "./lib/api";

const DEFAULT_DEVICE_ID = env.deviceId;

function AppShell() {
  const [isLoggedIn, setIsLoggedIn] = useState(false);
  const [currentUser, setCurrentUser] = useState(null);
  const [authError, setAuthError] = useState(null);
  const [authLoading, setAuthLoading] = useState(false);
  const [devices, setDevices] = useState([]);
  const [selectedDeviceId, setSelectedDeviceId] = useState(() =>
    localStorage.getItem("selected_device_id") || DEFAULT_DEVICE_ID,
  );
  const [deviceRole, setDeviceRole] = useState(null);
  const [deviceError, setDeviceError] = useState(null);

  const handleAuth = async (mode, payload) => {
    setAuthError(null);
    setAuthLoading(true);
    try {
      const data =
        mode === "login" ? await authLogin(payload) : await authRegister(payload);
      setIsLoggedIn(true);
      setCurrentUser(data);
    } catch (error) {
      setAuthError(
        error instanceof Error ? error.message : "Không thể đăng nhập.",
      );
    } finally {
      setAuthLoading(false);
    }
  };

  const handleLogout = () => {
    setIsLoggedIn(false);
    setCurrentUser(null);
    setDevices([]);
    setSelectedDeviceId(DEFAULT_DEVICE_ID);
    setDeviceRole(null);
  };

  const loadDevices = async () => {
    try {
      const data = await fetchDevices();
      setDevices(data);
      if (data.length > 0) {
        const preferred =
          data.find((item) => item.deviceId === selectedDeviceId) || data[0];
        setSelectedDeviceId(preferred.deviceId);
        setDeviceRole(preferred.role);
      } else {
        setSelectedDeviceId("");
        setDeviceRole(null);
      }
    } catch (error) {
      setDeviceError(
        error instanceof Error ? error.message : "Không thể tải danh sách thiết bị.",
      );
    }
  };

  const handleRegisterDevice = async (deviceId) => {
    if (!deviceId) {
      setDeviceError("Vui lòng nhập Device ID.");
      return;
    }

    setDeviceError(null);
    try {
      await registerDevice(deviceId);
      await loadDevices();
    } catch (error) {
      setDeviceError(
        error instanceof Error ? error.message : "Không thể đăng ký thiết bị.",
      );
    }
  };

  const handleSelectDevice = (deviceId) => {
    setSelectedDeviceId(deviceId);
    const match = devices.find((item) => item.deviceId === deviceId);
    setDeviceRole(match?.role || null);
  };

  const handleNavigateToStats = (deviceId) => {
    setSelectedDeviceId(deviceId);
    const match = devices.find((item) => item.deviceId === deviceId);
    setDeviceRole(match?.role || null);
    window.location.href = `/stats/${deviceId}`;
  };

  useEffect(() => {
    if (selectedDeviceId) {
      localStorage.setItem("selected_device_id", selectedDeviceId);
    }
  }, [selectedDeviceId]);

  useEffect(() => {
    if (isLoggedIn) {
      loadDevices();
    }
  }, [isLoggedIn]);

  return (
    <div className="page">
      {isLoggedIn && (
        <TopNav isLoggedIn={isLoggedIn} currentUser={currentUser} onLogout={handleLogout} />
      )}
      <Routes>
        <Route
          path="/"
          element={
            isLoggedIn ? (
              <DashboardPage
                selectedDeviceId={selectedDeviceId}
                deviceRole={deviceRole}
              />
            ) : (
              <Navigate to="/auth" replace />
            )
          }
        />
        <Route
          path="/profile"
          element={
            isLoggedIn ? (
              <ProfilePage
                devices={devices}
                selectedDeviceId={selectedDeviceId}
                onSelectDevice={handleSelectDevice}
                onRegisterDevice={handleRegisterDevice}
                deviceError={deviceError}
                onNavigateToStats={handleNavigateToStats}
              />
            ) : (
              <Navigate to="/auth" replace />
            )
          }
        />
        <Route
          path="/stats/:device_id?"
          element={
            isLoggedIn ? (
              <StatisticsPage
                devices={devices}
                selectedDeviceId={selectedDeviceId}
                onSelectDevice={handleSelectDevice}
              />
            ) : (
              <Navigate to="/auth" replace />
            )
          }
        />
        <Route
          path="/auth"
          element={
            isLoggedIn ? (
              <Navigate to="/" replace />
            ) : (
              <AuthPage onAuth={handleAuth} loading={authLoading} error={authError} />
            )
          }
        />
        <Route path="*" element={<Navigate to={isLoggedIn ? "/" : "/auth"} replace />} />
      </Routes>
    </div>
  );
}

export default function App() {
  return (
    <BrowserRouter>
      <AppShell />
    </BrowserRouter>
  );
}
