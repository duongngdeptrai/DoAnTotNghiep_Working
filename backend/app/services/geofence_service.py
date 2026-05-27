import math
from threading import RLock
from time import time


def _now_epoch() -> int:
    return int(time())


class GeofenceService:
    EARTH_RADIUS_M = 6371000

    def __init__(self, config_repo=None, center_lat=None, center_lng=None, radius_m=None, mode=None) -> None:
        self._config_repo = config_repo
        self._lock = RLock()

        # Default values
        default_lat = center_lat if center_lat is not None else 21.0285
        default_lng = center_lng if center_lng is not None else 105.8542
        default_radius = radius_m if radius_m is not None else 100.0
        default_mode = mode if mode is not None else "fixed"

        self._geofences = []

        # Try to load from database
        loaded_from_db = False
        if config_repo:
            db_config = config_repo.get_global_config()
            if db_config and "geofences" in db_config:
                self._geofences = db_config["geofences"]
                loaded_from_db = True
            elif db_config:
                # Migrate old single config to list
                self._geofences = [{
                    "id": "default",
                    "mode": db_config.get("mode", default_mode),
                    "centerLat": db_config.get("centerLat", default_lat),
                    "centerLng": db_config.get("centerLng", default_lng),
                    "radiusM": db_config.get("radiusM", default_radius),
                    "source": db_config.get("source", "fixed"),
                    "path": db_config.get("path", []),
                    "updatedAt": db_config.get("updatedAt", _now_epoch()),
                }]
                loaded_from_db = True

        if not loaded_from_db:
            self._geofences = [{
                "id": "default",
                "mode": default_mode,
                "centerLat": default_lat,
                "centerLng": default_lng,
                "radiusM": default_radius,
                "source": "fixed",
                "path": [],
                "updatedAt": _now_epoch(),
            }]
            if config_repo:
                self._save_to_db()

    def _save_to_db(self) -> None:
        """Save current geofences list to database as global config."""
        if not self._config_repo:
            return
        config_data = {
            "geofences": self._geofences,
            "updatedAt": _now_epoch(),
        }
        self._config_repo.upsert_global_config(config_data)

    def get_state(self) -> dict:
        with self._lock:
            # Return as a list of geofences
            return {"geofences": list(self._geofences)}

    def upsert_geofence(self, geofence_id: str, **kwargs) -> dict:
        with self._lock:
            idx = next((i for i, g in enumerate(self._geofences) if g["id"] == geofence_id), None)

            if idx is not None:
                # Update existing
                for key, value in kwargs.items():
                    if value is not None:
                        self._geofences[idx][key] = value
                self._geofences[idx]["updatedAt"] = _now_epoch()
            else:
                # Add new
                new_geofence = {
                    "id": geofence_id,
                    "name": kwargs.get("name", f"Vùng {len(self._geofences) + 1}"),
                    "mode": kwargs.get("mode", "fixed"),
                    "centerLat": kwargs.get("centerLat", 21.0285),
                    "centerLng": kwargs.get("centerLng", 105.8542),
                    "radiusM": kwargs.get("radiusM", 100.0),
                    "source": kwargs.get("source", "fixed"),
                    "path": kwargs.get("path", []),
                    "updatedAt": _now_epoch(),
                }
                # Update any other provided kwargs
                for key, value in kwargs.items():
                    new_geofence[key] = value
                self._geofences.append(new_geofence)

            if self._config_repo:
                self._save_to_db()
            return {"geofences": list(self._geofences)}

    def delete_geofence(self, geofence_id: str) -> dict:
        with self._lock:
            self._geofences = [g for g in self._geofences if g["id"] != geofence_id]
            if self._config_repo:
                self._save_to_db()
            return {"geofences": list(self._geofences)}

    def set_fixed_mode(self) -> dict:
        # For backward compatibility, we update the 'default' geofence
        return self.upsert_geofence("default", mode="fixed", source="fixed")

    def set_mobile_mode(self) -> dict:
        return self.upsert_geofence("default", mode="mobile")

    def update_mobile_center(self, lat: float, lng: float) -> dict:
        return self.upsert_geofence("default", mode="mobile", centerLat=lat, centerLng=lng, source="mobile")

    def update_path(self, path: list[list[float]]) -> dict:
        return self.upsert_geofence("default", path=path)

    def update_full_geofence(self, geofence_id: str, mode: str, radius_m: float, center_lat: float = None, center_lng: float = None, path: list = None) -> dict:
        with self._lock:
            idx = next((i for i, g in enumerate(self._geofences) if g["id"] == geofence_id), None)

            update_data = {
                "mode": mode,
                "radiusM": radius_m,
                "updatedAt": _now_epoch(),
            }

            if mode == "fixed":
                update_data["centerLat"] = center_lat if center_lat is not None else 21.0285
                update_data["centerLng"] = center_lng if center_lng is not None else 105.8542
                update_data["source"] = "fixed"
                update_data["path"] = [] # Clear path when in fixed mode
            elif mode == "mobile":
                update_data["source"] = "mobile"
                if path:
                    update_data["path"] = path
                elif center_lat is not None and center_lng is not None:
                    update_data["centerLat"] = center_lat
                    update_data["centerLng"] = center_lng
                else:
                    update_data["centerLat"] = 21.0285
                    update_data["centerLng"] = 105.8542

            if idx is not None:
                for key, value in update_data.items():
                    self._geofences[idx][key] = value
            else:
                # Create new if not exists
                new_geofence = {"id": geofence_id, **update_data}
                self._geofences.append(new_geofence)

            if self._config_repo:
                self._save_to_db()
            return {"geofences": list(self._geofences)}


    @classmethod
    def haversine_distance_m(
        cls,
        lat1: float,
        lng1: float,
        lat2: float,
        lng2: float,
    ) -> float:
        phi1 = math.radians(lat1)
        phi2 = math.radians(lat2)
        delta_phi = math.radians(lat2 - lat1)
        delta_lambda = math.radians(lng2 - lng1)

        a = (
            math.sin(delta_phi / 2) ** 2
            + math.cos(phi1) * math.cos(phi2) * math.sin(delta_lambda / 2) ** 2
        )
        c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
        return cls.EARTH_RADIUS_M * c

    def distance_from_center(self, lat: float, lng: float, state: dict | None = None) -> float:
        current_state = state or self.get_state()
        return self.haversine_distance_m(current_state["centerLat"], current_state["centerLng"], lat, lng)

    def _distance_to_segment(self, p: tuple[float, float], a: tuple[float, float], b: tuple[float, float]) -> float:
        # Simple approximation using Euclidean distance for small distances
        # P = (lat, lng), A = (lat, lng), B = (lat, lng)
        px, py = p
        ax, ay = a
        bx, by = b

        dx, dy = bx - ax, by - ay
        if dx == 0 and dy == 0:
            return self.haversine_distance_m(px, py, ax, ay)

        t = ((px - ax) * dx + (py - ay) * dy) / (dx * dx + dy * dy)
        t = max(0, min(1, t))

        nearest_lat = ax + t * dx
        nearest_lng = ay + t * dy

        return self.haversine_distance_m(px, py, nearest_lat, nearest_lng)

    def is_inside(self, lat: float, lng: float) -> tuple[bool, float]:
        with self._lock:
            geofences = list(self._geofences)

        if not geofences:
            return False, float("inf")

        overall_min_dist = float("inf")
        is_inside_any = False

        for g in geofences:
            mode = g.get("mode", "fixed")
            path = g.get("path", [])
            radius = g.get("radiusM", 100.0)

            if mode == "mobile" and path and len(path) >= 2:
                min_dist = float("inf")
                for i in range(len(path) - 1):
                    dist = self._distance_to_segment((lat, lng), tuple(path[i]), tuple(path[i+1]))
                    min_dist = min(min_dist, dist)
                distance = min_dist
            else:
                # Use the specific center for this geofence
                distance = self.haversine_distance_m(
                    g.get("centerLat", 21.0285),
                    g.get("centerLng", 105.8542),
                    lat,
                    lng
                )

            if distance <= radius:
                is_inside_any = True

            overall_min_dist = min(overall_min_dist, distance)

        return is_inside_any, overall_min_dist
