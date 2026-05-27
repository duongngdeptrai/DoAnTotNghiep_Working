from time import time
from pymongo import ReturnDocument


class GeofenceConfigRepository:
    def __init__(self, db) -> None:
        self.collection = db["geofence_configs"]
        # Ensure index on device_id for uniqueness
        self.collection.create_index([("device_id", 1)], unique=True)

    def get_global_config(self) -> dict | None:
        """Get the global geofence configuration (device_id=None)."""
        return self.collection.find_one({"device_id": None})

    def get_config_for_device(self, device_id: str) -> dict | None:
        """Get geofence configuration for a specific device."""
        return self.collection.find_one({"device_id": device_id})

    def upsert_global_config(self, config_data: dict) -> dict:
        """Create or update global geofence configuration."""
        now = int(time())
        config_data.setdefault("updated_at", now)
        config_data.setdefault("created_at", now)
        config_data["device_id"] = None

        result = self.collection.find_one_and_update(
            {"device_id": None},
            {"$set": config_data},
            upsert=True,
            return_document=ReturnDocument.AFTER,
        )
        return result

    def upsert_device_config(self, device_id: str, config_data: dict) -> dict:
        """Create or update device-specific geofence configuration."""
        now = int(time())
        config_data.setdefault("updated_at", now)
        config_data.setdefault("created_at", now)
        config_data["device_id"] = device_id

        result = self.collection.find_one_and_update(
            {"device_id": device_id},
            {"$set": config_data},
            upsert=True,
            return_document=ReturnDocument.AFTER,
        )
        return result

    def delete_config(self, device_id: str | None = None) -> bool:
        """Delete geofence configuration. If device_id is None, delete global config."""
        query = {"device_id": device_id} if device_id is not None else {"device_id": None}
        result = self.collection.delete_one(query)
        return result.deleted_count > 0
