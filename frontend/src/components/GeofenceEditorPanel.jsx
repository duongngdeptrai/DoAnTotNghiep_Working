import React from "react";

export default function GeofenceEditorPanel({
  pendingConfig,
  editingGeofenceId,
  geofenceState,
  isOwner,
  isPlanMode,
  modeError,
  onUpdateConfig,
  onSave,
  onCancel,
  onRemoveLastPoint,
  onStartPlanMode,
  onEditGeofence,
  onDeleteGeofence,
  onSetMode,
  onSetRadius,
  onSetPath,
}) {
  const editingGeofence = editingGeofenceId
    ? geofenceState.geofences?.find((g) => g.id === editingGeofenceId)
    : null;
  const isNew = !editingGeofence;

  return (
    <div className="geofence-editor-panel">
      <div className="editor-panel-header">
        <h4>{isNew ? "Thêm vùng an toàn mới" : `Chỉnh sửa: ${editingGeofence?.name || ""}`}</h4>
        <button className="close-btn" onClick={onCancel} type="button">✕</button>
      </div>

      <div className="editor-panel-content">
        <div className="editor-group">
          <label className="editor-label">Tên vùng an toàn</label>
          <input
            type="text"
            className="editor-input"
            value={pendingConfig.name || ""}
            onChange={(e) => onUpdateConfig({ name: e.target.value })}
            placeholder="Nhập tên vùng..."
          />
        </div>

        <div className="editor-group">
          <label className="editor-label">Chế độ vùng</label>
          <div className="editor-mode-toggle">
            <button
              className={`editor-mode-btn ${pendingConfig.mode === "circle" ? "active" : ""}`}
              onClick={() => onUpdateConfig({ mode: "circle" })}
              type="button"
            >
              📍 Hình tròn
            </button>
            <button
              className={`editor-mode-btn ${pendingConfig.mode === "path" ? "active" : ""}`}
              onClick={() => onUpdateConfig({ mode: "path" })}
              type="button"
            >
              🛣️ Đường đi
            </button>
          </div>
        </div>

        <div className="editor-group">
          <label className="editor-label">Bán kính an toàn</label>
          <div className="radius-controls">
            <input
              type="range"
              className="editor-radius-slider"
              min="10"
              max="5000"
              step="10"
              value={pendingConfig.radius}
              onChange={(e) => onUpdateConfig({ radius: parseInt(e.target.value, 10) })}
            />
            <div className="radius-number-row">
              <input
                type="number"
                className="editor-input radius-input"
                value={pendingConfig.radius}
                onChange={(e) => onUpdateConfig({ radius: parseInt(e.target.value, 10) || 0 })}
                min="10"
                max="5000"
              />
              <span className="editor-unit">m</span>
            </div>
          </div>
        </div>

        {pendingConfig.mode === "path" && (
          <div className="editor-group path-group">
            <label className="editor-label">Số điểm vẽ: {pendingConfig.path?.length || 0}</label>
            <button
              className="remove-point-btn"
              onClick={onRemoveLastPoint}
              disabled={!pendingConfig.path || pendingConfig.path.length < 2}
              type="button"
            >
              🗑️ Xóa điểm cuối cùng
            </button>
          </div>
        )}

        {modeError && (
          <div className="editor-error">
            <span className="error-icon">⚠️</span>
            <span>{modeError}</span>
          </div>
        )}
      </div>

      <div className="editor-footer">
        <button className="editor-btn editor-btn-save" onClick={onSave}>
          Lưu thay đổi
        </button>
        <button className="editor-btn editor-btn-cancel" onClick={onCancel}>
          Hủy bỏ
        </button>
      </div>
    </div>
  );
}
