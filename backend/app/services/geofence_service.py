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

        default_lat = center_lat if center_lat is not None else 21.0285
        default_lng = center_lng if center_lng is not None else 105.8542
        default_radius = radius_m if radius_m is not None else 100.0
        default_mode = mode if mode is not None else "fixed"

        self._geofences = []

        loaded_from_db = False
        if config_repo:
            db_config = config_repo.get_global_config()
            if db_config and "geofences" in db_config:
                self._geofences = db_config["geofences"]
                loaded_from_db = True
            elif db_config:
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
        if not self._config_repo:
            return
        config_data = {
            "geofences": self._geofences,
            "updatedAt": _now_epoch(),
        }
        self._config_repo.upsert_global_config(config_data)

    def _extract_center(self, state: dict):
        geofences = state.get("geofences", [])
        g = geofences[0] if geofences else {}
        return g.get("centerLat", 21.0285), g.get("centerLng", 105.8542)

    def get_state(self) -> dict:
        with self._lock:
            return {"geofences": list(self._geofences)}

    def upsert_geofence(self, geofence_id: str, **kwargs) -> dict:
        with self._lock:
            idx = next((i for i, g in enumerate(self._geofences) if g["id"] == geofence_id), None)

            if idx is not None:
                for key, value in kwargs.items():
                    if value is not None:
                        self._geofences[idx][key] = value
                self._geofences[idx]["updatedAt"] = _now_epoch()
            else:
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

    def _get_default(self) -> dict | None:
        return next((g for g in self._geofences if g.get("id") == "default"), None)

    def set_fixed_mode(self) -> dict:
        with self._lock:
            current = self._get_default() or {}
            lat = current.get("fixedCenterLat", current.get("centerLat", 21.0285))
            lng = current.get("fixedCenterLng", current.get("centerLng", 105.8542))
            return self.upsert_geofence(
                "default", mode="fixed", source="fixed", centerLat=lat, centerLng=lng
            )

    def set_mobile_mode(self) -> dict:
        with self._lock:
            current = self._get_default() or {}
            lat = current.get("mobileCenterLat", current.get("centerLat", 21.0285))
            lng = current.get("mobileCenterLng", current.get("centerLng", 105.8542))
            return self.upsert_geofence(
                "default", mode="mobile", radiusM=50.0, centerLat=lat, centerLng=lng
            )

    def update_center(self, lat: float, lng: float) -> dict:
        """Cập nhật tâm vùng 'default'. Ghi đồng thời vào ô nhớ riêng của
        mode hiện tại (fixedCenter* hoặc mobileCenter*) để lần chuyển mode
        sau còn khôi phục lại đúng tâm cũ thay vì bị mode kia ghi đè."""
        with self._lock:
            current = self._get_default() or {}
            mode = current.get("mode", "fixed")
            if mode == "mobile":
                return self.upsert_geofence(
                    "default", centerLat=lat, centerLng=lng,
                    mobileCenterLat=lat, mobileCenterLng=lng,
                )
            return self.upsert_geofence(
                "default", centerLat=lat, centerLng=lng,
                fixedCenterLat=lat, fixedCenterLng=lng,
            )

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
                update_data["source"] = "fixed"
                if path and len(path) >= 2:
                    update_data["path"] = path
                    update_data["centerLat"] = center_lat if center_lat is not None else 21.0285
                    update_data["centerLng"] = center_lng if center_lng is not None else 105.8542
                else:
                    update_data["centerLat"] = center_lat if center_lat is not None else 21.0285
                    update_data["centerLng"] = center_lng if center_lng is not None else 105.8542
                    update_data["path"] = []
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

            # Đồng bộ vào ô nhớ riêng của mode để set_fixed_mode()/set_mobile_mode()
            # sau này khôi phục đúng center vừa sửa qua Plan Mode Editor, thay vì
            # khôi phục giá trị fixedCenter*/mobileCenter* cũ đã lỗi thời.
            if geofence_id == "default" and "centerLat" in update_data:
                if mode == "fixed":
                    update_data["fixedCenterLat"] = update_data["centerLat"]
                    update_data["fixedCenterLng"] = update_data["centerLng"]
                elif mode == "mobile":
                    update_data["mobileCenterLat"] = update_data["centerLat"]
                    update_data["mobileCenterLng"] = update_data["centerLng"]

            if idx is not None:
                for key, value in update_data.items():
                    self._geofences[idx][key] = value
            else:
                new_geofence = {"id": geofence_id, **update_data}
                self._geofences.append(new_geofence)

            if self._config_repo:
                self._save_to_db()
            return {"geofences": list(self._geofences)}

    @classmethod
    def haversine_distance_m(cls, lat1: float, lng1: float, lat2: float, lng2: float) -> float:
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
        center_lat, center_lng = self._extract_center(current_state)
        return self.haversine_distance_m(center_lat, center_lng, lat, lng)

    def _distance_to_segment(self, p: tuple[float, float], a: tuple[float, float], b: tuple[float, float]) -> float:
        px, py = p   # (lat, lng)
        ax, ay = a   # (lat, lng)
        bx, by = b   # (lat, lng)

        if (bx - ax) == 0 and (by - ay) == 0:
            return self.haversine_distance_m(px, py, ax, ay)

        # Scale lng differences by cos(lat) so both axes are in comparable degree-equivalent units.
        # Without this, the dot-product mixes lat degrees with lng degrees which have
        # different metric lengths (~111.3 km/° lat vs ~103.9 km/° lng at Vietnam's latitude).
        cos_lat = math.cos(math.radians((ax + bx) / 2))

        dx = bx - ax
        dy = (by - ay) * cos_lat   # scaled to be comparable to lat degrees
        qx = px - ax
        qy = (py - ay) * cos_lat

        t = (qx * dx + qy * dy) / (dx * dx + dy * dy)
        t = max(0.0, min(1.0, t))

        nearest_lat = ax + t * (bx - ax)
        nearest_lng = ay + t * (by - ay)

        return self.haversine_distance_m(px, py, nearest_lat, nearest_lng)

    def is_inside(self, lat: float, lng: float) -> tuple[bool, float, str | None]:
        with self._lock:
            geofences = list(self._geofences)

            if not geofences:
                return False, float("inf"), None

            overall_min_dist = float("inf")
            matched_geofence_id = None

            for g in geofences:
                path = g.get("path", [])
                radius = g.get("radiusM", 100.0)
                gid = g.get("id", "unknown")

                if path and len(path) >= 2:
                    min_dist = float("inf")
                    for i in range(len(path) - 1):
                        dist = self._distance_to_segment((lat, lng), tuple(path[i]), tuple(path[i + 1]))
                        min_dist = min(min_dist, dist)
                    distance = min_dist
                else:
                    distance = self.haversine_distance_m(
                        g.get("centerLat", 21.0285), g.get("centerLng", 105.8542),
                        lat, lng,
                    )

                if distance <= radius:
                    if matched_geofence_id is None:
                        matched_geofence_id = gid

                overall_min_dist = min(overall_min_dist, distance)

            is_inside_any = matched_geofence_id is not None
            return is_inside_any, overall_min_dist, matched_geofence_id
