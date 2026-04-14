import json
import logging

import paho.mqtt.client as mqtt

from app.core.config import Settings
from app.services.location_processor import LocationProcessor


logger = logging.getLogger(__name__)


class MQTTService:
    def __init__(self, settings: Settings, processor: LocationProcessor) -> None:
        self.settings = settings
        self.processor = processor
        self.client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2)
        self._is_started = False

        if settings.mqtt_username and settings.mqtt_password:
            self.client.username_pw_set(settings.mqtt_username, settings.mqtt_password)

        self.client.on_connect = self.on_connect
        self.client.on_message = self.on_message
        self.client.on_disconnect = self.on_disconnect

    def start(self) -> None:
        if self._is_started:
            return

        self.client.connect(self.settings.mqtt_host, self.settings.mqtt_port, self.settings.mqtt_keepalive)
        self.client.loop_start()
        self._is_started = True
        logger.info("MQTT service started")

    def stop(self) -> None:
        if not self._is_started:
            return

        self.client.loop_stop()
        self.client.disconnect()
        self._is_started = False
        logger.info("MQTT service stopped")

    def on_connect(self, client: mqtt.Client, userdata, flags, reason_code, properties) -> None:
        if reason_code == 0:
            client.subscribe(self.settings.mqtt_topic)
            logger.info(f"[MQTT:CONNECT] Connected and subscribed to: {self.settings.mqtt_topic}")
        else:
            logger.error(f"[MQTT:CONNECT] Connection failed with code: {reason_code}")

    def on_disconnect(self, client: mqtt.Client, userdata, flags, reason_code, properties) -> None:
        logger.warning(f"[MQTT:DISCONNECT] Code: {reason_code}")

    def on_message(self, client: mqtt.Client, userdata, msg: mqtt.MQTTMessage) -> None:
        try:
            payload = json.loads(msg.payload.decode("utf-8"))
            logger.debug(f"[MQTT:MSG] {msg.topic}: {payload}")
            self.processor.process(payload)
        except json.JSONDecodeError as exc:
            logger.error(f"[MQTT:ERR] JSON decode failed on topic {msg.topic}: {exc}")
        except Exception as exc:
            logger.error(f"[MQTT:ERR] Error processing message on {msg.topic}: {exc}")
