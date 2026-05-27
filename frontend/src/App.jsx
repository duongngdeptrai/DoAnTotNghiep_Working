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
  fetchMe,
  registerDevice,
} from "./lib/api";

const DEFAULT_DEVICE_ID = env.deviceId;

function AppShell() {
  const [token, setToken] = useState(() => localStorage.getItem("auth_token"));
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
      localStorage.setItem("auth_token", data.access_token);
      setToken(data.access_token);
      setCurrentUser(data.user);
    } catch (error) {
      setAuthError(error instanceof Error ? error.message : "Không thể đăng nhập.");
    } finally {
      setAuthLoading(false);
    }
  };

  const handleLogout = () => {
    localStorage.removeItem("auth_token");
    setToken(null);
    setCurrentUser(null);
    setDevices([]);
    setSelectedDeviceId(DEFAULT_DEVICE_ID);
    setDeviceRole(null);
  };

  const loadDevices = async (nextToken) => {
    try {
      const data = await fetchDevices(nextToken);
      setDevices(data);
      if (data.length > 0) {
        const preferred = data.find((item) => item.deviceId === selectedDeviceId) || data[0];
        setSelectedDeviceId(preferred.deviceId);
        setDeviceRole(preferred.role);
      } else {
        setSelectedDeviceId("");
        setDeviceRole(null);
      }
    } catch (error) {
      setDeviceError(error instanceof Error ? error.message : "Không thể tải danh sách thiết bị.");
    }
  };

  const handleRegisterDevice = async (deviceId) => {
    if (!deviceId || !token) {
      setDeviceError("Không có token đăng nhập. Vui lòng đăng nhập lại.");
      return;
    }

    setDeviceError(null);
    try {
      await registerDevice(token, deviceId);
      await loadDevices(token);
    } catch (error) {
      setDeviceError(error instanceof Error ? error.message : "Không thể đăng ký thiết bị.");
    }
  };

  const handleSelectDevice = (deviceId) => {
    setSelectedDeviceId(deviceId);
    const match = devices.find((item) => item.deviceId === deviceId);
    setDeviceRole(match?.role || null);
  };

  useEffect(() => {
    if (!token) {
      return;
    }
    fetchMe(token)
      .then((data) => setCurrentUser(data))
      .catch(() => undefined);
  }, [token]);

  useEffect(() => {
    if (!token) {
      return;
    }
    loadDevices(token);
  }, [token]);

  useEffect(() => {
    if (selectedDeviceId) {
      localStorage.setItem("selected_device_id", selectedDeviceId);
    }
  }, [selectedDeviceId]);

  return (
    <div className="page">
      {token && <TopNav token={token} currentUser={currentUser} onLogout={handleLogout} />}
      <Routes>
        <Route
          path="/"
          element={
            token ? (
              <DashboardPage
                token={token}
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
            token ? (
              <ProfilePage
                devices={devices}
                selectedDeviceId={selectedDeviceId}
                onSelectDevice={handleSelectDevice}
                onRegisterDevice={handleRegisterDevice}
                deviceError={deviceError}
              />
            ) : (
              <Navigate to="/auth" replace />
            )
          }
        />
        <Route
          path="/stats/:device_id?"
          element={
            token ? (
              <StatisticsPage
                token={token}
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
            token ? (
              <Navigate to="/" replace />
            ) : (
              <AuthPage onAuth={handleAuth} loading={authLoading} error={authError} />
            )
          }
        />
        <Route path="*" element={<Navigate to={token ? "/" : "/auth"} replace />} />
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
