import math


class GeofenceService:
    EARTH_RADIUS_M = 6371000

    def __init__(self, center_lat: float, center_lng: float, radius_m: float) -> None:
        self.center_lat = center_lat
        self.center_lng = center_lng
        self.radius_m = radius_m

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

    def distance_from_center(self, lat: float, lng: float) -> float:
        return self.haversine_distance_m(self.center_lat, self.center_lng, lat, lng)

    def is_inside(self, lat: float, lng: float) -> tuple[bool, float]:
        distance = self.distance_from_center(lat, lng)
        return distance <= self.radius_m, distance
