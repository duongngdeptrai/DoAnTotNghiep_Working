import math
from threading import RLock
from time import time


def _now_epoch() -> int:
    return int(time())


class GeofenceService:
    EARTH_RADIUS_M = 6371000

    def __init__(self, center_lat: float, center_lng: float, radius_m: float, mode: str = "fixed") -> None:
        self._fixed_center_lat = center_lat
        self._fixed_center_lng = center_lng
        self._lock = RLock()
        self._state = {
            "mode": mode,
            "centerLat": center_lat,
            "centerLng": center_lng,
            "radiusM": radius_m,
            "source": "fixed",
            "updatedAt": _now_epoch(),
        }

    def _update_state(
        self,
        *,
        mode: str | None = None,
        center_lat: float | None = None,
        center_lng: float | None = None,
        radius_m: float | None = None,
        source: str | None = None,
    ) -> dict:
        with self._lock:
            if mode is not None:
                self._state["mode"] = mode
            if center_lat is not None:
                self._state["centerLat"] = center_lat
            if center_lng is not None:
                self._state["centerLng"] = center_lng
            if radius_m is not None:
                self._state["radiusM"] = radius_m
            if source is not None:
                self._state["source"] = source
            self._state["updatedAt"] = _now_epoch()
            return dict(self._state)

    def get_state(self) -> dict:
        with self._lock:
            return dict(self._state)

    def set_fixed_mode(self) -> dict:
        return self._update_state(
            mode="fixed",
            center_lat=self._fixed_center_lat,
            center_lng=self._fixed_center_lng,
            source="fixed",
        )

    def set_mobile_mode(self) -> dict:
        return self._update_state(mode="mobile")

    def update_mobile_center(self, lat: float, lng: float) -> dict:
        return self._update_state(
            mode="mobile",
            center_lat=lat,
            center_lng=lng,
            source="mobile",
        )

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

    def is_inside(self, lat: float, lng: float) -> tuple[bool, float]:
        state = self.get_state()
        distance = self.distance_from_center(lat, lng, state)
        return distance <= state["radiusM"], distance
