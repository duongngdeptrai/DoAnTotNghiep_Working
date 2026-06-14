import logging
import smtplib
from email.mime.text import MIMEText

import requests

from app.core.config import Settings

logger = logging.getLogger(__name__)

EVENT_LABELS = {
    "outside_entered": "Thiết bị đã rời khỏi vùng an toàn",
    "outside_reminder": "Nhắc nhở: Thiết bị vẫn đang ngoài vùng an toàn",
    "outside_still": "",
    "inside_entered": "Thiết bị đã vào vùng an toàn",
    "inside_moved": "Thiết bị đã chuyển sang vùng an toàn khác",
    "inside_still": "",
}


class NotificationService:
    def __init__(self, settings: Settings, device_config_repo=None) -> None:
        self.settings = settings
        self.device_config_repo = device_config_repo

    def send_telegram(self, message: str) -> None:
        if not self.settings.telegram_bot_token or not self.settings.telegram_chat_id:
            return

        url = f"https://api.telegram.org/bot{self.settings.telegram_bot_token}/sendMessage"
        payload = {
            "chat_id": self.settings.telegram_chat_id,
            "text": message,
        }

        try:
            requests.post(url, json=payload, timeout=10)
        except requests.RequestException as exc:
            logger.error("Failed to send Telegram alert: %s", exc)

    def send_email(self, subject: str, body: str, to_email: str = None) -> None:
        if not to_email:
            to_email = self.settings.smtp_to_email

        if not all(
            [
                self.settings.smtp_host,
                self.settings.smtp_username,
                self.settings.smtp_password,
                to_email,
                self.settings.smtp_from_email,
            ]
        ):
            return

        msg = MIMEText(body)
        msg["Subject"] = subject
        msg["From"] = self.settings.smtp_from_email
        msg["To"] = to_email

        try:
            with smtplib.SMTP(self.settings.smtp_host, self.settings.smtp_port, timeout=15) as server:
                server.starttls()
                server.login(self.settings.smtp_username, self.settings.smtp_password)
                server.sendmail(
                    self.settings.smtp_from_email,
                    [to_email],
                    msg.as_string(),
                )
        except Exception as exc:
            logger.error("Failed to send Email alert: %s", exc)

    def _get_parent_email(self, device_id: str) -> str | None:
        if self.device_config_repo:
            config = self.device_config_repo.get_config(device_id)
            if config is not None:
                if not config.get("alertEnabled", True):
                    return None
                return config.get("parentEmail") or self.settings.smtp_to_email
        return self.settings.smtp_to_email

    def send_sos_alert(self, device_id: str, lat: float, lng: float, timestamp: int, no_gps: bool = False) -> None:
        dt = self._format_timestamp(timestamp)
        if no_gps:
            message = (
                f"🆘 SOS KHẨN CẤP!\n"
                f"Thiết bị: {device_id}\n"
                f"⚠️ Chưa có tín hiệu GPS\n"
                f"Thời gian: {dt}"
            )
        else:
            maps_url = f"https://maps.google.com/?q={lat:.6f},{lng:.6f}"
            message = (
                f"🆘 SOS KHẨN CẤP!\n"
                f"Thiết bị: {device_id}\n"
                f"Vị trí: {lat:.6f}, {lng:.6f}\n"
                f"Thời gian: {dt}\n"
                f"🗺 {maps_url}"
            )
        logger.warning("SOS received from %s: lat=%s lng=%s", device_id, lat, lng)
        self.send_telegram(message)

    def _format_timestamp(self, timestamp: int) -> str:
        from datetime import datetime, timezone, timedelta
        VN_TZ = timezone(timedelta(hours=7))
        MIN_VALID_TS = 1577836800  # 2020-01-01 UTC
        if timestamp and timestamp >= MIN_VALID_TS:
            return datetime.fromtimestamp(timestamp, tz=VN_TZ).strftime("%d/%m/%Y %H:%M:%S (GMT+7)")
        return datetime.now(tz=VN_TZ).strftime("%d/%m/%Y %H:%M:%S (GMT+7)")

    def send_geofence_alert(self, device_id: str, lat: float, lng: float, timestamp: int, event: str, geofence_id: str | None = None, geofence_name: str | None = None) -> None:
        label = EVENT_LABELS.get(event, event)
        if not label:
            return  # sự kiện không cần thông báo (inside_still, outside_still)

        dt = self._format_timestamp(timestamp)
        maps_url = f"https://maps.google.com/?q={lat:.6f},{lng:.6f}"
        zone_line = f"Vùng: {geofence_name}\n" if geofence_name else ""

        EVENT_ICONS = {
            "outside_entered":  "⚠️",
            "outside_reminder": "🔔",
            "inside_entered":   "✅",
            "inside_moved":     "📍",
        }
        icon = EVENT_ICONS.get(event, "📌")

        telegram_message = (
            f"{icon} {label}\n"
            f"Thiết bị: {device_id}\n"
            f"{zone_line}"
            f"Vị trí: {lat:.6f}, {lng:.6f}\n"
            f"Thời gian: {dt}\n"
            f"🗺 {maps_url}"
        )
        self.send_telegram(telegram_message)

        # Gửi email riêng — không ảnh hưởng đến Telegram nếu email chưa cấu hình
        parent_email = self._get_parent_email(device_id)
        if parent_email:
            email_subject = f"{icon} {label} — {device_id}"
            email_body = (
                f"Thiết bị: {device_id}\n"
                f"Sự kiện: {label}\n"
                f"{zone_line}"
                f"Vị trí: {lat:.6f}, {lng:.6f}\n"
                f"Thời gian: {dt}\n"
                f"Xem bản đồ: {maps_url}\n"
            )
            self.send_email(email_subject, email_body, parent_email)
