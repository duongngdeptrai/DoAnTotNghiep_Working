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

    def send_geofence_alert(self, device_id: str, lat: float, lng: float, timestamp: int, event: str, geofence_id: str | None = None) -> None:
        parent_email = self._get_parent_email(device_id)
        if not parent_email:
            logger.warning(f"No email configured for device {device_id}")
            return

        label = EVENT_LABELS.get(event, event)

        geofence_info = f" [{geofence_id}]" if geofence_id else ""
        telegram_message = (
            f"ALERT [{event}]{geofence_info}: Device {device_id} - {label}\n"
            f"Vi tri: {lat:.6f}, {lng:.6f} (ts={timestamp})"
        )

        email_subject = f"Cảnh báo Geofence: {device_id} - {label}{geofence_info}"
        email_body = (
            f"Thiet bi: {device_id}\n"
            f"Su kien: {event}{geofence_info}\n"
            f"Mo ta: {label}\n"
            f"Vi tri: {lat:.6f}, {lng:.6f}\n"
            f"Thoi gian: {timestamp}\n"
        )

        self.send_telegram(telegram_message)
        self.send_email(email_subject, email_body, parent_email)
