import json
import logging
import time

import paho.mqtt.client as mqtt

from app.core.config import Settings
from app.services.location_processor import LocationProcessor
from app.services.notification_service import NotificationService

logger = logging.getLogger(__name__)


class MQTTService:
    def __init__(self, settings: Settings, processor: LocationProcessor, notification_service: NotificationService) -> None:
        self.settings = settings
        self.processor = processor
        self.notification_service = notification_service
        self.client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2)
        self._is_started = False

        if settings.mqtt_username and settings.mqtt_password:
            self.client.username_pw_set(settings.mqtt_username, settings.mqtt_password)

        if settings.mqtt_tls:
            self.client.tls_set()

        self.client.on_connect = self._on_connect
        self.client.on_message = self._on_message
        self.client.on_disconnect = self._on_disconnect

    def start(self) -> None:
        if self._is_started:
            return

        max_retries = 5
        for attempt in range(1, max_retries + 1):
            try:
                logger.info(
                    "MQTT connecting to %s:%d (attempt %d/%d, tls=%s)",
                    self.settings.mqtt_host,
                    self.settings.mqtt_port,
                    attempt,
                    max_retries,
                    self.settings.mqtt_tls,
                )
                self.client.connect(
                    self.settings.mqtt_host,
                    self.settings.mqtt_port,
                    self.settings.mqtt_keepalive,
                )
                self.client.loop_start()
                self._is_started = True
                logger.info("MQTT service started")
                return
            except Exception as exc:
                logger.error("MQTT connection failed (attempt %d/%d): %s", attempt, max_retries, exc)
                if attempt < max_retries:
                    wait = min(2 ** attempt, 30)
                    logger.info("Retrying in %ds...", wait)
                    time.sleep(wait)

        logger.error("MQTT connection failed after %d attempts — service not started", max_retries)

    def stop(self) -> None:
        if not self._is_started:
            return

        self.client.loop_stop()
        self.client.disconnect()
        self._is_started = False
        logger.info("MQTT service stopped")

    def _on_connect(self, client: mqtt.Client, userdata, flags, reason_code, properties) -> None:
        if reason_code == 0:
            client.subscribe(self.settings.mqtt_topic)
            client.subscribe(self.settings.mqtt_sos_topic)
            logger.info("[MQTT:CONNECT] Connected and subscribed to: %s + %s", self.settings.mqtt_topic, self.settings.mqtt_sos_topic)
        else:
            logger.error("[MQTT:CONNECT] Connection failed with code: %s", reason_code)

    def _on_disconnect(self, client: mqtt.Client, userdata, flags, reason_code, properties) -> None:
        logger.warning("[MQTT:DISCONNECT] Code: %s", reason_code)

    def _on_message(self, client: mqtt.Client, userdata, msg: mqtt.MQTTMessage) -> None:
        try:
            payload = json.loads(msg.payload.decode("utf-8"))
            logger.debug("[MQTT:MSG] %s: %s", msg.topic, payload)

            if msg.topic.startswith("sos/"):
                self.notification_service.send_sos_alert(
                    device_id=payload.get("deviceId", msg.topic.split("/")[-1]),
                    lat=float(payload.get("lat", 0)),
                    lng=float(payload.get("lng", 0)),
                    timestamp=int(payload.get("timestamp", 0)),
                    no_gps=bool(payload.get("noGps", False)),
                )
            else:
                self.processor.process(payload)
        except json.JSONDecodeError as exc:
            logger.error("[MQTT:ERR] JSON decode failed on topic %s: %s", msg.topic, exc)
        except Exception as exc:
            logger.error("[MQTT:ERR] Error processing message on %s: %s", msg.topic, exc)
