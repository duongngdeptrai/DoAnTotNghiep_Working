import { useState, useMemo } from "react";

export default function ProfilePage({
  devices,
  selectedDeviceId,
  onSelectDevice,
  onRegisterDevice,
  deviceError,
}) {
  const [newDeviceId, setNewDeviceId] = useState("");
  const [searchTerm, setSearchTerm] = useState("");
  const [filterRole, setFilterRole] = useState("all");

  const handleRegister = () => {
    if (!newDeviceId) return;
    onRegisterDevice(newDeviceId);
    setNewDeviceId("");
  };

  const filteredDevices = useMemo(() => {
    return devices?.filter((d) => {
      const matchesSearch = d.deviceId.toLowerCase().includes(searchTerm.toLowerCase());
      const matchesRole = filterRole === "all" || d.role === filterRole;
      return matchesSearch && matchesRole;
    }) || [];
  }, [devices, searchTerm, filterRole]);

  return (
    <div className="page profile-page">
      <div className="profile-header">
        <div className="header-text">
          <h1>Quản lý thiết bị</h1>
          <p className="muted">Quản lý, đăng ký và chia sẻ các thiết bị theo dõi của bạn.</p>
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
              <button className="primary-button" onClick={handleRegister} type="button">
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
                className={`device-card ${selectedDeviceId === device.deviceId ? 'active' : ''}`}
                onClick={() => onSelectDevice(device.deviceId)}
              >
                <div className="card-top">
                  <div className="device-avatar">
                    {device.deviceId.charAt(0).toUpperCase()}
                  </div>
                  <div className="role-badge" data-role={device.role}>
                    {device.role === 'owner' ? 'Owner' : 'Shared'}
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
                  <button className="secondary-button" type="button">Chi tiết</button>
                </div>
              </div>
            ))
          )}
        </div>
      </div>
    </div>
  );
}
