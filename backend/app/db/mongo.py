from pymongo import MongoClient
from pymongo.collection import Collection
from pymongo.database import Database

from app.core.config import get_settings


class MongoManager:
    def __init__(self) -> None:
        self.client: MongoClient | None = None
        self.db: Database | None = None

    def connect(self) -> None:
        settings = get_settings()
        self.client = MongoClient(settings.mongo_uri)
        self.db = self.client[settings.mongo_db_name]
        self._ensure_indexes()

    def close(self) -> None:
        if self.client is not None:
            self.client.close()

    def get_collection(self, name: str) -> Collection:
        if self.db is None:
            raise RuntimeError("MongoDB is not initialized")
        return self.db[name]

    def _ensure_indexes(self) -> None:
        locations = self.get_collection("locations")
        locations.create_index([("deviceId", 1), ("timestamp", -1)])
        locations.create_index(
            [("deviceId", 1), ("timestamp", 1), ("lat", 1), ("lng", 1)],
            unique=True,
            name="uniq_device_time_coord",
        )
        # TTL index: auto-delete records older than 90 days (in seconds)
        locations.create_index("receivedAt", expireAfterSeconds=90 * 24 * 3600)

        device_configs = self.get_collection("device_configs")
        device_configs.create_index("deviceId", unique=True)

        geofence_configs = self.get_collection("geofence_configs")
        geofence_configs.create_index([("deviceId", 1), ("is_active", 1)])
        geofence_configs.create_index([("name", 1)])

        users = self.get_collection("users")
        users.create_index("email", unique=True)

        permissions = self.get_collection("device_permissions")
        permissions.create_index([("deviceId", 1), ("userId", 1)], unique=True)
        permissions.create_index([("userId", 1), ("role", 1)])


mongo_manager = MongoManager()
