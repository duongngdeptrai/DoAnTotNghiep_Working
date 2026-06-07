from dataclasses import dataclass, field
from time import time

from app.services.geofence_service import GeofenceService


@dataclass
class DeviceState:
    is_outside: bool = True
    last_alert_at: float = 0.0
    last_lat: float | None = None
    last_lng: float | None = None
    current_geofence_id: str | None = None


class AlertStateService:
    def __init__(self, cooldown_sec: int, noise_threshold_m: float, repeat_outside: bool) -> None:
        self.cooldown_sec = cooldown_sec
        self.noise_threshold_m = noise_threshold_m
        self.repeat_outside = repeat_outside
        self._states: dict[str, DeviceState] = {}

    def _get_state(self, device_id: str) -> DeviceState:
        if device_id not in self._states:
            self._states[device_id] = DeviceState()
        return self._states[device_id]

    def should_ignore_as_noise(self, device_id: str, lat: float, lng: float) -> bool:
        state = self._get_state(device_id)
        if state.last_lat is None or state.last_lng is None:
            return False

        distance = GeofenceService.haversine_distance_m(state.last_lat, state.last_lng, lat, lng)
        return distance < self.noise_threshold_m

    def update_last_location(self, device_id: str, lat: float, lng: float) -> None:
        state = self._get_state(device_id)
        state.last_lat = lat
        state.last_lng = lng

    def evaluate_alert(self, device_id: str, is_inside: bool, geofence_id: str | None) -> tuple[bool, str]:
        state = self._get_state(device_id)
        now = time()
        is_outside = not is_inside

        prev_gf_id = state.current_geofence_id

        if state.is_outside and is_outside:
            if self.repeat_outside and (now - state.last_alert_at) >= self.cooldown_sec:
                state.last_alert_at = now
                return True, "outside_reminder"
            return False, "outside_still"

        if not state.is_outside and is_outside:
            state.is_outside = True
            state.last_alert_at = now
            state.current_geofence_id = None
            return True, "outside_entered"

        if state.is_outside and is_inside:
            state.is_outside = False
            state.current_geofence_id = geofence_id
            return True, "inside_entered"

        if not state.is_outside and is_inside:
            if prev_gf_id != geofence_id:
                state.current_geofence_id = geofence_id
                return True, "inside_moved"

        return False, "inside_still"
