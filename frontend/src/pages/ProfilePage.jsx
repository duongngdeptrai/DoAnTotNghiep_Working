import { useState } from "react";
import {
  shareDevice,
  fetchDeviceConfig,
  postDeviceConfig,
  deleteDeviceConfig,
} from "../lib/api";

export default function ProfilePage({
  devices,
  selectedDeviceId,
  onSelectDevice,
  onRegisterDevice,
  deviceError,
  onNavigateToStats,
}) {
  const [newDeviceId, setNewDeviceId] = useState("");
  const [searchTerm, setSearchTerm] = useState("");
  const [filterRole, setFilterRole] = useState("all");
  const [shareModal, setShareModal] = useState({ open: false, deviceId: null });
  const [shareEmail, setShareEmail] = useState("");
  const [shareLoading, setShareLoading] = useState(false);
  const [shareError, setShareError] = useState(null);
  const [configModal, setConfigModal] = useState({ open: false, deviceId: null });
  const [configEmail, setConfigEmail] = useState("");
  const [configAlertEnabled, setConfigAlertEnabled] = useState(true);
  const [configLoading, setConfigLoading] = useState(false);
  const [configError, setConfigError] = useState(null);
  const [configSaved, setConfigSaved] = useState(false);

  const handleRegister = () => {
    if (!newDeviceId) return;
    onRegisterDevice(newDeviceId);
    setNewDeviceId("");
  };

  const openShareModal = (deviceId) => {
    setShareModal({ open: true, deviceId });
    setShareEmail("");
    setShareError(null);
  };

  const handleShare = async () => {
    if (!shareEmail || !shareModal.deviceId) return;
    setShareLoading(true);
    setShareError(null);
    try {
      await shareDevice(shareModal.deviceId, shareEmail);
      setShareEmail("");
      setShareError(null);
    } catch (err) {
      setShareError(err.message);
    } finally {
      setShareLoading(false);
    }
  };

  const openConfigModal = async (deviceId) => {
    setConfigModal({ open: true, deviceId });
    setConfigError(null);
    setConfigSaved(false);
    try {
      const data = await fetchDeviceConfig(deviceId);
      setConfigEmail(data.parentEmail || "");
      setConfigAlertEnabled(data.alertEnabled ?? true);
    } catch {
      setConfigEmail("");
      setConfigAlertEnabled(true);
    }
  };

  const handleSaveConfig = async () => {
    if (!configModal.deviceId) return;
    setConfigLoading(true);
    setConfigError(null);
    try {
      await postDeviceConfig(
        configModal.deviceId,
        configEmail,
        configAlertEnabled,
      );
      setConfigSaved(true);
      setTimeout(() => setConfigSaved(false), 2000);
    } catch (err) {
      setConfigError(err.message);
    } finally {
      setConfigLoading(false);
    }
  };

  const handleDeleteConfig = async () => {
    if (!configModal.deviceId) return;
    setConfigLoading(true);
    setConfigError(null);
    try {
      await deleteDeviceConfig(configModal.deviceId);
      setConfigEmail("");
      setConfigAlertEnabled(true);
      setConfigSaved(true);
      setTimeout(() => setConfigSaved(false), 2000);
    } catch (err) {
      setConfigError(err.message);
    } finally {
      setConfigLoading(false);
    }
  };

  const filteredDevices = devices?.filter((d) => {
    const matchesSearch = d.deviceId.toLowerCase().includes(searchTerm.toLowerCase());
    const matchesRole = filterRole === "all" || d.role === filterRole;
    return matchesSearch && matchesRole;
  }) || [];

  return (
    <div className="page profile-page">
      <div className="profile-header">
        <div className="header-text">
          <h1>Quản lý thiết bị</h1>
          <p className="muted">
            Quản lý, đăng ký và chia sẻ các thiết bị theo dõi của bạn.
          </p>
        </div>
        <div className="header-actions">
          <div className="search-box">
            <span className="search-icon">🔍</span>
            <input
              type="text"
              placeholder="Tìm device ID..."
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
            />
          </div>
          <select
            className="role-filter"
            value={filterRole}
            onChange={(e) => setFilterRole(e.target.value)}
          >
            <option value="all">Tất cả quyền</option>
            <option value="owner">Chủ sở hữu</option>
            <option value="shared">Được chia sẻ</option>
          </select>
        </div>
      </div>

      <div className="profile-content">
        <div className="device-registration-card">
          <h3>➕ Đăng ký thiết bị mới</h3>
          <div className="reg-form">
            <div className="input-group">
              <input
                value={newDeviceId}
                onChange={(event) => setNewDeviceId(event.target.value)}
                placeholder="Nhập Device ID (ví dụ: child_01)"
              />
              <button
                className="primary-button"
                onClick={handleRegister}
                type="button"
              >
                Đăng ký
              </button>
            </div>
            {deviceError && <p className="error-text">{deviceError}</p>}
          </div>
        </div>

        <div className="device-grid">
          {filteredDevices.length === 0 ? (
            <div className="empty-devices">
              <div className="empty-icon">📦</div>
              <h3>Không tìm thấy thiết bị</h3>
              <p>Thử thay đổi từ khóa tìm kiếm hoặc đăng ký thiết bị mới.</p>
            </div>
          ) : (
            filteredDevices.map((device) => (
              <div
                key={device.deviceId}
                className={`device-card ${selectedDeviceId === device.deviceId ? "active" : ""}`}
                onClick={() => onSelectDevice(device.deviceId)}
              >
                <div className="card-top">
                  <div className="device-avatar">
                    {device.deviceId.charAt(0).toUpperCase()}
                  </div>
                  <div className="role-badge" data-role={device.role}>
                    {device.role === "owner" ? "Owner" : "Shared"}
                  </div>
                </div>
                <div className="card-body">
                  <div className="device-id-label">{device.deviceId}</div>
                  <div className="device-status">
                    <span className="status-dot"></span>
                    <span className="status-text">Đang kết nối</span>
                  </div>
                </div>
                <div className="card-footer">
                  <button
                    className="secondary-button"
                    type="button"
                    onClick={(e) => {
                      e.stopPropagation();
                      onNavigateToStats(device.deviceId);
                    }}
                  >
                    Chi tiết
                  </button>
                  {device.role === "owner" && (
                    <>
                      <button
                        className="secondary-button share-btn"
                        type="button"
                        onClick={(e) => {
                          e.stopPropagation();
                          openShareModal(device.deviceId);
                        }}
                      >
                        🔗 Chia sẻ
                      </button>
                      <button
                        className="secondary-button config-btn"
                        type="button"
                        onClick={(e) => {
                          e.stopPropagation();
                          openConfigModal(device.deviceId);
                        }}
                      >
                        🔔 Thông báo
                      </button>
                    </>
                  )}
                </div>
              </div>
            ))
          )}
        </div>
      </div>

      {shareModal.open && (
        <div
          className="modal-overlay"
          onClick={() => setShareModal({ open: false, deviceId: null })}
        >
          <div className="modal-dialog" onClick={(e) => e.stopPropagation()}>
            <h3>Chia sẻ thiết bị</h3>
            <p className="muted">
              Chia sẻ <strong>{shareModal.deviceId}</strong> với người dùng khác
              bằng email.
            </p>
            <div className="input-group">
              <input
                type="email"
                placeholder="Nhập email người dùng..."
                value={shareEmail}
                onChange={(e) => setShareEmail(e.target.value)}
              />
              <button
                className="primary-button"
                onClick={handleShare}
                disabled={shareLoading}
                type="button"
              >
                {shareLoading ? "Đang chia sẻ..." : "Chia sẻ"}
              </button>
            </div>
            {shareError && <p className="error-text">{shareError}</p>}
            <button
              className="secondary-button close-btn"
              onClick={() => setShareModal({ open: false, deviceId: null })}
              type="button"
            >
              Đóng
            </button>
          </div>
        </div>
      )}

      {configModal.open && (
        <div
          className="modal-overlay"
          onClick={() => setConfigModal({ open: false, deviceId: null })}
        >
          <div className="modal-dialog" onClick={(e) => e.stopPropagation()}>
            <h3>Cấu hình thông báo</h3>
            <p className="muted">
              Thiết lập email nhận cảnh báo cho <strong>{configModal.deviceId}</strong>.
            </p>
            <div className="config-form">
              <label>Email phụ huynh</label>
              <input
                type="email"
                placeholder="email@example.com"
                value={configEmail}
                onChange={(e) => setConfigEmail(e.target.value)}
              />
              <div className="toggle-row">
                <span>Bật thông báo email</span>
                <button
                  className={`toggle ${configAlertEnabled ? "on" : "off"}`}
                  onClick={() => setConfigAlertEnabled(!configAlertEnabled)}
                  type="button"
                >
                  {configAlertEnabled ? "Bật" : "Tắt"}
                </button>
              </div>
              {configError && <p className="error-text">{configError}</p>}
              {configSaved && <p className="success-text">Đã lưu cấu hình!</p>}
              <div className="config-actions">
                <button
                  className="primary-button"
                  onClick={handleSaveConfig}
                  disabled={configLoading}
                  type="button"
                >
                  {configLoading ? "Đang lưu..." : "Lưu"}
                </button>
                {configEmail && (
                  <button
                    className="secondary-button danger-btn"
                    onClick={handleDeleteConfig}
                    disabled={configLoading}
                    type="button"
                  >
                    Xóa cấu hình
                  </button>
                )}
              </div>
            </div>
            <button
              className="secondary-button close-btn"
              onClick={() => setConfigModal({ open: false, deviceId: null })}
              type="button"
            >
              Đóng
            </button>
          </div>
        </div>
      )}
    </div>
  );
}
