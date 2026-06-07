from functools import lru_cache
import re
from typing import List
from pydantic import Field, field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    app_name: str = "Child Tracking Backend"
    app_host: str = "0.0.0.0"
    app_port: int = 8001

    cors_origins: List[str] = Field(default_factory=lambda: [
        "http://localhost:5173",
        "http://localhost:64123",
        "http://localhost:65000",
        "http://127.0.0.1:5173",
        "http://127.0.0.1:64123",
        "http://127.0.0.1:65000",
        "http://localhost:8080",
        "http://127.0.0.1:8080",
        "http://localhost:64124",
        "http://localhost:65001",
        "http://192.168.76.41:8080",
        "https://doantotnghiep-working.onrender.com",
    ])

    mongo_uri: str = "mongodb://localhost:27017"
    mongo_db_name: str = "child_tracking"

    mqtt_host: str = "localhost"
    mqtt_port: int = 1883
    mqtt_username: str | None = None
    mqtt_password: str | None = None
    mqtt_topic: str = "gps/#"
    mqtt_keepalive: int = 60
    mqtt_tls: bool = False

    geofence_mode: str = "fixed"
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

    jwt_secret_key: str = "change-me"
    jwt_algorithm: str = "HS256"
    jwt_access_token_exp_minutes: int = 60

    default_device_id: str = "child_01"
    default_device_email: str | None = None

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )


@field_validator("cors_origins", mode="before")
@classmethod
def parse_origins(cls, value: str | list[str]) -> list[str]:
    if isinstance(value, list):
        return value
    text = value.strip()
    if text.startswith("[") and text.endswith("]"):
        text = text[1:-1]
    parts = re.split(r'[,\s]+', text.strip('"').strip("'"))
    return [p.strip().strip('"').strip("'") for p in parts if p.strip()]


@lru_cache(maxsize=1)
def get_settings() -> Settings:
    return Settings()
