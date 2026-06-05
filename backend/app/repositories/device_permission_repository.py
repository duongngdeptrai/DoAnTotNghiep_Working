import logging
from time import time
from bson import ObjectId
from pymongo.errors import DuplicateKeyError

from app.db.mongo import mongo_manager

logger = logging.getLogger(__name__)


class DevicePermissionRepository:
    def __init__(self) -> None:
        self.collection = mongo_manager.get_collection("device_permissions")

    def _to_object_id(self, user_id: str) -> ObjectId:
        return ObjectId(user_id)

    def is_device_registered(self, device_id: str) -> bool:
        return self.collection.find_one({"deviceId": device_id, "role": "owner"}) is not None

    def get_owner(self, device_id: str) -> dict | None:
        return self.collection.find_one({"deviceId": device_id, "role": "owner"})

    def get_role_for_user(self, device_id: str, user_id: str) -> str | None:
        record = self.collection.find_one({"deviceId": device_id, "userId": self._to_object_id(user_id)})
        if not record:
            return None
        return record.get("role")

    def list_devices_for_user(self, user_id: str) -> list[dict]:
        cursor = self.collection.find({"userId": self._to_object_id(user_id)}, projection={"_id": 0})
        devices = list(cursor)
        logger.info(f"list_devices_for_user {user_id}: found {len(devices)} devices")
        return devices

    def get_device_ids_for_user(self, user_id: str) -> set[str]:
        cursor = self.collection.find(
            {"userId": self._to_object_id(user_id)},
            projection={"_id": 0, "deviceId": 1},
        )
        return {item["deviceId"] for item in cursor}

    def get_owner_device_ids(self, user_id: str) -> set[str]:
        cursor = self.collection.find(
            {"userId": self._to_object_id(user_id), "role": "owner"},
            projection={"_id": 0, "deviceId": 1},
        )
        return {item["deviceId"] for item in cursor}

    def user_has_owner_device(self, user_id: str) -> bool:
        return (
            self.collection.find_one({"userId": self._to_object_id(user_id), "role": "owner"})
            is not None
        )

    def add_owner(self, device_id: str, user_id: str) -> dict:
        existing_owner = self.get_owner(device_id)
        if existing_owner and str(existing_owner.get("userId")) != user_id:
            logger.warning(f"Device {device_id} already owned by different user")
            raise ValueError("device_owned")

        now = int(time())
        payload = {
            "deviceId": device_id,
            "userId": self._to_object_id(user_id),
            "role": "owner",
            "createdAt": now,
        }
        try:
            result = self.collection.insert_one(payload)
            logger.info(f"Inserted device owner: {device_id} for user {user_id}, inserted_id: {result.inserted_id}")
        except DuplicateKeyError as e:
            logger.warning(f"Duplicate key error for device {device_id} user {user_id}: {e}")
            pass
        return payload

    def add_shared(self, device_id: str, user_id: str) -> dict:
        now = int(time())
        payload = {
            "deviceId": device_id,
            "userId": self._to_object_id(user_id),
            "role": "shared",
            "createdAt": now,
        }
        try:
            result = self.collection.insert_one(payload)
            logger.info(f"Inserted device shared: {device_id} for user {user_id}, inserted_id: {result.inserted_id}")
        except DuplicateKeyError as e:
            logger.warning(f"Duplicate key error for shared {device_id} user {user_id}: {e}")
            pass
        return payload

    def remove_shared(self, device_id: str, user_id: str) -> bool:
        result = self.collection.delete_one(
            {"deviceId": device_id, "userId": self._to_object_id(user_id), "role": "shared"}
        )
        return result.deleted_count > 0

def remove_device(self, device_id: str, user_id: str) -> bool:
  result = self.collection.delete_many({
    "deviceId": device_id,
    "userId": self._to_object_id(user_id),
  })
  return result.deleted_count > 0
