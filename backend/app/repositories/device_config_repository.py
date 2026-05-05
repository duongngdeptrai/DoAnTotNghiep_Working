from time import time
from pymongo import ReturnDocument


class DeviceConfigRepository:
    def __init__(self, db) -> None:
        self.collection = db["device_configs"]

    def upsert_config(self, device_id: str, parent_email: str, alert_enabled: bool = True) -> dict:
        """Create or update device config with parent email and alert settings."""
        now = int(time())
        result = self.collection.find_one_and_update(
            {"deviceId": device_id},
            {
                "$set": {
                    "parentEmail": parent_email,
                    "alertEnabled": alert_enabled,
                    "updatedAt": now,
                },
                "$setOnInsert": {
                    "createdAt": now,
                },
            },
            upsert=True,
            return_document=ReturnDocument.AFTER,
        )
        return result

    def get_config(self, device_id: str) -> dict | None:
        """Get config for a specific device."""
        return self.collection.find_one({"deviceId": device_id})

    def delete_config(self, device_id: str) -> bool:
        """Delete device config."""
        result = self.collection.delete_one({"deviceId": device_id})
        return result.deleted_count > 0
