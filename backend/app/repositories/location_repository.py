from datetime import datetime, timezone, timedelta

VN_TZ = timezone(timedelta(hours=7))
from typing import Optional
from pymongo.errors import DuplicateKeyError
import math

from app.db.mongo import mongo_manager
from app.models.location import LocationDB


def haversine_distance(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """Calculate distance between two points on Earth in meters."""
    R = 6371000  # Earth radius in meters
    phi1 = math.radians(lat1)
    phi2 = math.radians(lat2)
    delta_phi = math.radians(lat2 - lat1)
    delta_lambda = math.radians(lon2 - lon1)

    a = math.sin(delta_phi / 2) ** 2 + math.cos(phi1) * math.cos(phi2) * math.sin(delta_lambda / 2) ** 2
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))

    return R * c


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

    def get_track_path(
        self, device_id: str, start: int, end: int
    ) -> list[dict]:
        """Get ordered track path points within time range."""
        cursor = self.collection.find(
            {"deviceId": device_id, "timestamp": {"$gte": start, "$lte": end}},
            projection={"_id": 0, "deviceId": 0, "insideGeofence": 0, "distanceFromCenterM": 0, "receivedAt": 0},
        ).sort("timestamp", 1)
        return list(cursor)

    def get_statistics(
        self, device_id: str, start: int, end: int
    ) -> dict:
        """Calculate comprehensive statistics for device within time range."""
        points = self.get_track_path(device_id, start, end)

        if not points:
            return {
                "totalPoints": 0,
                "totalDistanceM": 0.0,
                "activeDurationSec": 0,
                "avgSpeedKmh": None,
                "stopCount": 0,
                "outsideCount": 0,
            }

        total_points = len(points)
        first_ts = points[0]["timestamp"]
        last_ts = points[-1]["timestamp"]
        duration_sec = max(0, last_ts - first_ts)

        # Calculate total distance
        total_distance_m = 0.0
        stop_count = 0
        SPEED_THRESHOLD_KMH = 1.0  # below this = stop

        for i in range(1, total_points):
            p1 = points[i - 1]
            p2 = points[i]
            dist_m = haversine_distance(p1["lat"], p1["lng"], p2["lat"], p2["lng"])
            total_distance_m += dist_m

            # Estimate speed between these two points
            time_diff = p2["timestamp"] - p1["timestamp"]
            if time_diff > 0:
                speed_kmh = (dist_m / 1000) / (time_diff / 3600)
                if speed_kmh < SPEED_THRESHOLD_KMH:
                    stop_count += 1

        avg_speed_kmh = None
        if duration_sec > 0:
            avg_speed_kmh = (total_distance_m / 1000) / (duration_sec / 3600)
            if avg_speed_kmh < 0.01:  # effectively zero
                avg_speed_kmh = 0.0

        # Count inside→outside geofence transitions
        geofence_cursor = self.collection.find(
            {"deviceId": device_id, "timestamp": {"$gte": start, "$lte": end}},
            projection={"_id": 0, "insideGeofence": 1},
        ).sort("timestamp", 1)

        outside_count = 0
        prev_inside: bool | None = None
        for gp in geofence_cursor:
            inside = gp.get("insideGeofence", True)
            if prev_inside is True and inside is False:
                outside_count += 1
            prev_inside = inside

        return {
            "totalPoints": total_points,
            "totalDistanceM": round(total_distance_m, 2),
            "activeDurationSec": duration_sec,
            "avgSpeedKmh": round(avg_speed_kmh, 2) if avg_speed_kmh is not None else None,
            "stopCount": stop_count,
            "outsideCount": outside_count,
        }

    def get_aggregated_stats(
        self, device_id: str, start: int, end: int, interval: str = "day"
    ) -> list[dict]:
        """Get aggregated statistics based on the provided interval (hour, day, week, year).
        Returns all intervals in range, filling missing ones with zeros.
        """
        # Get all points in range sorted by timestamp
        cursor = self.collection.find(
            {"deviceId": device_id, "timestamp": {"$gte": start, "$lte": end}},
            projection={"_id": 0, "deviceId": 0, "insideGeofence": 0, "distanceFromCenterM": 0, "receivedAt": 0},
        ).sort("timestamp", 1)
        points = list(cursor)

        # Helper to format date string based on interval
        def format_label(dt, interval):
            if interval == "hour":
                return dt.strftime("%Y-%m-%d %H:00")
            if interval == "day":
                return dt.strftime("%Y-%m-%d")
            if interval == "week":
                # ISO week: Year-WeekNumber
                return dt.strftime("%Y-W%U")
            if interval == "year":
                return dt.strftime("%Y")
            return dt.strftime("%Y-%m-%d")

        # Group points by the chosen interval — use VN_TZ so day boundaries align with Vietnam time
        aggregated_groups = {}
        for p in points:
            dt = datetime.fromtimestamp(p["timestamp"], tz=VN_TZ)
            label = format_label(dt, interval)
            if label not in aggregated_groups:
                aggregated_groups[label] = []
            aggregated_groups[label].append(p)

        # Generate ALL labels in range (also in VN_TZ)
        all_labels = []
        current = datetime.fromtimestamp(start, tz=VN_TZ)
        end_dt = datetime.fromtimestamp(end, tz=VN_TZ)

        while current <= end_dt:
            label = format_label(current, interval)
            if label not in all_labels:
                all_labels.append(label)

            if interval == "hour":
                current += timedelta(hours=1)
            elif interval == "day":
                current += timedelta(days=1)
            elif interval == "week":
                current += timedelta(weeks=1)
            elif interval == "year":
                # Move to next year
                current = current.replace(year=current.year + 1, month=1, day=1, hour=0, minute=0, second=0)
            else:
                current += timedelta(days=1)

        # Build result array
        results = []
        for label in all_labels:
            if label in aggregated_groups:
                group_points = aggregated_groups[label]
                point_count = len(group_points)
                duration = max(0, group_points[-1]["timestamp"] - group_points[0]["timestamp"])

                total_dist_m = 0.0
                for i in range(1, len(group_points)):
                    p1 = group_points[i - 1]
                    p2 = group_points[i]
                    total_dist_m += haversine_distance(p1["lat"], p1["lng"], p2["lat"], p2["lng"])

                results.append({
                    "label": label,
                    "pointCount": point_count,
                    "totalDistanceM": round(total_dist_m, 2),
                    "activeDurationSec": duration,
                })
            else:
                results.append({
                    "label": label,
                    "pointCount": 0,
                    "totalDistanceM": 0.0,
                    "activeDurationSec": 0,
                })

        return results

    def get_heatmap_data(
        self, device_id: str, start: int, end: int, bucket_size: float = 0.0005
    ) -> list[dict]:
        """
        Get heatmap data by bucketing points into grid cells.
        bucket_size in degrees (0.0005 ≈ 50m at equator).
        Returns list of {lat, lng, weight} sorted by weight desc.
        """
        pipeline = [
            {"$match": {"deviceId": device_id, "timestamp": {"$gte": start, "$lte": end}}},
            {
                "$project": {
                    "latBucket": {"$floor": {"$divide": ["$lat", bucket_size]}},
                    "lngBucket": {"$floor": {"$divide": ["$lng", bucket_size]}},
                }
            },
            {"$group": {"_id": {"lat": "$latBucket", "lng": "$lngBucket"}, "weight": {"$sum": 1}}},
            {"$sort": {"weight": -1}},
            {"$limit": 1000},
        ]

        results = list(self.collection.aggregate(pipeline))
        heatmap_points = []

        for r in results:
            lat_center = r["_id"]["lat"] * bucket_size + bucket_size / 2
            lng_center = r["_id"]["lng"] * bucket_size + bucket_size / 2
            heatmap_points.append({
                "lat": round(lat_center, 6),
                "lng": round(lng_center, 6),
                "weight": r["weight"],
            })

        return heatmap_points
