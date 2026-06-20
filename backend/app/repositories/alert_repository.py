from time import time

from app.db.mongo import mongo_manager


class AlertRepository:
    def __init__(self) -> None:
        self.collection = mongo_manager.get_collection("alerts")

    def insert_alert(
        self,
        device_id: str,
        event: str,
        lat: float,
        lng: float,
        timestamp: int,
        geofence_id: str | None = None,
        geofence_name: str | None = None,
        alert_type: str = "geofence_alert",
    ) -> None:
        self.collection.insert_one({
            "deviceId": device_id,
            "type": alert_type,
            "event": event,
            "lat": lat,
            "lng": lng,
            "timestamp": timestamp,
            "geofenceId": geofence_id,
            "geofenceName": geofence_name,
            "receivedAt": int(time()),
        })

    def get_alerts_by_device(self, device_id: str, limit: int = 50) -> list[dict]:
        cursor = self.collection.find(
            {"deviceId": device_id},
            projection={"_id": 0},
        ).sort("receivedAt", -1).limit(limit)
        return list(cursor)

    def delete_alerts_by_device(self, device_id: str) -> int:
        result = self.collection.delete_many({"deviceId": device_id})
        return result.deleted_count
