import { useEffect, useRef } from "react";
import { createPortal } from "react-dom";

const EVENT_LABELS = {
  outside_entered: "Rời khỏi vùng an toàn",
  outside_reminder: "Vẫn đang ngoài vùng an toàn",
  inside_entered: "Đã đến",
  inside_moved: "Đã chuyển đến",
};

function getToastMessage(event, deviceId, zoneName) {
  const zone = zoneName || "vùng an toàn";
  switch (event) {
    case "outside_entered":
      return `${deviceId} đã rời khỏi vùng an toàn`;
    case "outside_reminder":
      return `${deviceId} vẫn đang ngoài vùng an toàn`;
    case "inside_entered":
      return `${deviceId} đã đến ${zone}`;
    case "inside_moved":
      return `${deviceId} đã chuyển đến ${zone}`;
    default:
      return `Cảnh báo từ ${deviceId}`;
  }
}

function ToastItem({ toast, onDismiss }) {
  const { id, alert, zoneName } = toast;
  const isOutside = alert.event?.startsWith("outside");
  const timerRef = useRef(null);

  useEffect(() => {
    timerRef.current = setTimeout(() => onDismiss(id), 5000);
    return () => clearTimeout(timerRef.current);
  }, [id, onDismiss]);

  const message = getToastMessage(alert.event, alert.deviceId, zoneName);
  const label = EVENT_LABELS[alert.event] || "Cảnh báo";

  return (
    <div className={`notification-toast ${isOutside ? "toast-outside" : "toast-inside"}`}>
      <div className="toast-header">
        <span className="toast-icon">{isOutside ? "⚠️" : "✅"}</span>
        <span className="toast-label">{label}</span>
        <button className="toast-close" onClick={() => onDismiss(id)}>✕</button>
      </div>
      <div className="toast-body">{message}</div>
      <div className="toast-progress">
        <div className="toast-progress-bar" />
      </div>
    </div>
  );
}

export default function NotificationToast({ toasts, onDismiss }) {
  if (!toasts || toasts.length === 0) return null;

  return createPortal(
    <div className="notification-toast-container">
      {toasts.map((toast) => (
        <ToastItem key={toast.id} toast={toast} onDismiss={onDismiss} />
      ))}
    </div>,
    document.body,
  );
}
