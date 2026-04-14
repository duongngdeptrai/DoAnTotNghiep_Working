import logging
import smtplib
from email.mime.text import MIMEText

import requests

from app.core.config import Settings


logger = logging.getLogger(__name__)


class NotificationService:
    def __init__(self, settings: Settings) -> None:
        self.settings = settings

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

    def send_email(self, subject: str, body: str) -> None:
        if not all(
            [
                self.settings.smtp_host,
                self.settings.smtp_username,
                self.settings.smtp_password,
                self.settings.smtp_to_email,
                self.settings.smtp_from_email,
            ]
        ):
            return

        msg = MIMEText(body)
        msg["Subject"] = subject
        msg["From"] = self.settings.smtp_from_email
        msg["To"] = self.settings.smtp_to_email

        try:
            with smtplib.SMTP(self.settings.smtp_host, self.settings.smtp_port, timeout=15) as server:
                server.starttls()
                server.login(self.settings.smtp_username, self.settings.smtp_password)
                server.sendmail(
                    self.settings.smtp_from_email,
                    [self.settings.smtp_to_email],
                    msg.as_string(),
                )
        except Exception as exc:
            logger.error("Failed to send Email alert: %s", exc)

    def send_geofence_alert(self, device_id: str, lat: float, lng: float, timestamp: int, event: str) -> None:
        telegram_message = (
            f"ALERT: Device {device_id} left safe zone at {lat:.6f}, {lng:.6f} "
            f"(ts={timestamp}, event={event})"
        )

        email_subject = "Geofence Alert"
        email_body = (
            f"Device: {device_id}\n"
            f"Latitude: {lat:.6f}\n"
            f"Longitude: {lng:.6f}\n"
            f"Timestamp: {timestamp}\n"
            f"Event: {event}"
        )

        self.send_telegram(telegram_message)
        self.send_email(email_subject, email_body)
