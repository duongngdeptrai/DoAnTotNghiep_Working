from functools import lru_cache
from typing import List

from pydantic import Field, field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    app_name: str = "Child Tracking Backend"
    app_host: str = "0.0.0.0"
    app_port: int = 8000
    cors_origins: List[str] = Field(default_factory=lambda: ["http://localhost:5173"])

    mongo_uri: str = "mongodb://localhost:27017"
    mongo_db_name: str = "child_tracking"

    mqtt_host: str = "localhost"
    mqtt_port: int = 1883
    mqtt_username: str | None = None
    mqtt_password: str | None = None
    mqtt_topic: str = "gps/#"
    mqtt_keepalive: int = 60

    geofence_center_lat: float = 21.0285
    geofence_center_lng: float = 105.8542
    geofence_radius_m: float = 100.0
    noise_threshold_m: float = 5.0
    alert_cooldown_sec: int = 60
    alert_repeat_outside: bool = False

    telegram_bot_token: str | None = None
    telegram_chat_id: str | None = None

    smtp_host: str | None = None
    smtp_port: int = 587
    smtp_username: str | None = None
    smtp_password: str | None = None
    smtp_from_email: str | None = None
    smtp_to_email: str | None = None

    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")

    @field_validator("cors_origins", mode="before")
    @classmethod
    def parse_origins(cls, value: str | list[str]) -> list[str]:
        if isinstance(value, str):
            return [item.strip() for item in value.split(",") if item.strip()]
        return value


@lru_cache(maxsize=1)
def get_settings() -> Settings:
    return Settings()
