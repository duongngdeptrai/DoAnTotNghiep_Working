from datetime import datetime, timezone
from pymongo.errors import DuplicateKeyError

from app.db.mongo import mongo_manager
from app.models.location import LocationDB


class LocationRepository:
    def __init__(self) -> None:
        self.collection = mongo_manager.get_collection("locations")

    def insert_location(self, location: LocationDB) -> bool:
        payload = location.model_dump()
        if "receivedAt" not in payload:
            payload["receivedAt"] = int(datetime.now(tz=timezone.utc).timestamp())

        try:
            self.collection.insert_one(payload)
            return True
        except DuplicateKeyError:
            return False

    def get_latest_by_device(self, device_id: str) -> dict | None:
        return self.collection.find_one({"deviceId": device_id}, sort=[("timestamp", -1)], projection={"_id": 0})

    def get_history_by_device(self, device_id: str, limit: int = 100) -> list[dict]:
        cursor = self.collection.find(
            {"deviceId": device_id},
            projection={"_id": 0},
        ).sort("timestamp", -1).limit(limit)
        return list(cursor)
