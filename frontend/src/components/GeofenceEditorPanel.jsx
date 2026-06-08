import React from "react";

export default function GeofenceEditorPanel({
  pendingConfig,
  editingGeofenceId,
  geofenceState,
  isOwner,
  isPlanMode,
  modeError,
  updatePendingConfig,
  onSaveGeofence,
  onCancelPlanMode,
  removeLastPoint,
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

      {!isPlanMode && (
        <>
          <div className="editor-panel-header">
            <h4>Vùng an toàn</h4>
          </div>

          <div className="editor-panel-content">
            <div className="geofence-list">
              {geofenceState.geofences?.length > 0 ? (
                geofenceState.geofences.map((geofence) => (
                  <div key={geofence.id} className="geofence-item">
                    <div className="geofence-info">
                      <span>{geofence.mode === "mobile" ? "🛣️" : "📍"}</span>
                      <div>
                        <div className="geofence-name">{geofence.name || geofence.id}</div>
                        <div className="geofence-mode">
                          {geofence.mode === "mobile"
                            ? "Đường đi"
                            : `Hình tròn · ${geofence.radiusM ?? "?"}m`}
                        </div>
                      </div>
                    </div>
                    {isOwner && (
                      <div>
                        <button
                          className="delete-gf-btn"
                          style={{ color: "var(--accent)" }}
                          onClick={() => onEditGeofence(geofence)}
                          type="button"
                          title="Chỉnh sửa"
                        >
                          ✏️
                        </button>
                        <button
                          className="delete-gf-btn"
                          onClick={() => onDeleteGeofence(geofence.id)}
                          type="button"
                          title="Xóa"
                        >
                          🗑️
                        </button>
                      </div>
                    )}
                  </div>
                ))
              ) : (
                <p className="muted">Chưa có vùng an toàn nào</p>
              )}
            </div>
          </div>

          {isOwner && (
            <div className="editor-footer">
              <button
                className="add-geofence-btn"
                onClick={onStartPlanMode}
                type="button"
              >
                ➕ Thêm vùng an toàn mới
              </button>
            </div>
          )}
        </>
      )}

      {isPlanMode && (
        <>
          <div className="editor-panel-header">
            <h4>{isNew ? "Thêm vùng an toàn mới" : `Chỉnh sửa: ${editingGeofence?.name || ""}`}</h4>
            <button className="close-btn" onClick={onCancelPlanMode} type="button">✕</button>
          </div>

          <div className="editor-panel-content">
            <div className="editor-group">
              <label className="editor-label">Tên vùng an toàn</label>
              <input
                type="text"
                className="editor-input"
                value={pendingConfig.name || ""}
                onChange={(e) => updatePendingConfig({ name: e.target.value })}
                placeholder="Nhập tên vùng..."
              />
            </div>

            <div className="editor-group">
              <label className="editor-label">Chế độ vùng</label>
              <div className="editor-mode-toggle">
                <button
                  className={`editor-mode-btn ${pendingConfig.mode === "circle" ? "active" : ""}`}
                  onClick={() => updatePendingConfig({ mode: "circle" })}
                  type="button"
                >
                  📍 Hình tròn
                </button>
                <button
                  className={`editor-mode-btn ${pendingConfig.mode === "path" ? "active" : ""}`}
                  onClick={() => updatePendingConfig({ mode: "path" })}
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
                  onChange={(e) => updatePendingConfig({ radius: parseInt(e.target.value, 10) })}
                />
                <div className="radius-number-row">
                  <input
                    type="number"
                    className="editor-input radius-input"
                    value={pendingConfig.radius}
                    onChange={(e) =>
                      updatePendingConfig({ radius: parseInt(e.target.value, 10) || 0 })
                    }
                    min="10"
                    max="5000"
                  />
                  <span className="editor-unit">m</span>
                </div>
              </div>
            </div>

            {pendingConfig.mode === "path" && (
              <div className="editor-group path-group">
                <label className="editor-label">
                  Số điểm vẽ: {pendingConfig.path?.length || 0}
                </label>
                <button
                  className="remove-point-btn"
                  onClick={removeLastPoint}
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
            <button className="editor-btn editor-btn-save" onClick={onSaveGeofence}>
              Lưu thay đổi
            </button>
            <button className="editor-btn editor-btn-cancel" onClick={onCancelPlanMode}>
              Hủy bỏ
            </button>
          </div>
        </>
      )}

    </div>
  );
}
