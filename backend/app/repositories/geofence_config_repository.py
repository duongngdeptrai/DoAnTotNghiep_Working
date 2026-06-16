from time import time
from pymongo import ReturnDocument


class GeofenceConfigRepository:
    def __init__(self, db, user_id: str | None = None) -> None:
        self.collection = db["geofence_configs"]
        self._user_id = user_id
        # Compound unique index scoped per user
        try:
            self.collection.drop_index("device_id_1")
        except Exception:
            pass
        self.collection.create_index([("user_id", 1), ("device_id", 1)], unique=True)

    def get_global_config(self) -> dict | None:
        return self.collection.find_one({"user_id": self._user_id, "device_id": None})

    def get_config_for_device(self, device_id: str) -> dict | None:
        return self.collection.find_one({"user_id": self._user_id, "device_id": device_id})

    def upsert_global_config(self, config_data: dict) -> dict:
        now = int(time())
        config_data.setdefault("updated_at", now)
        config_data.setdefault("created_at", now)
        config_data["user_id"] = self._user_id
        config_data["device_id"] = None

        result = self.collection.find_one_and_update(
            {"user_id": self._user_id, "device_id": None},
            {"$set": config_data},
            upsert=True,
            return_document=ReturnDocument.AFTER,
        )
        return result

    def upsert_device_config(self, device_id: str, config_data: dict) -> dict:
        now = int(time())
        config_data.setdefault("updated_at", now)
        config_data.setdefault("created_at", now)
        config_data["user_id"] = self._user_id
        config_data["device_id"] = device_id

        result = self.collection.find_one_and_update(
            {"user_id": self._user_id, "device_id": device_id},
            {"$set": config_data},
            upsert=True,
            return_document=ReturnDocument.AFTER,
        )
        return result

    def delete_config(self, device_id: str | None = None) -> bool:
        query = {"user_id": self._user_id, "device_id": device_id}
        result = self.collection.delete_one(query)
        return result.deleted_count > 0
