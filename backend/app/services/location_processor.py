from datetime import datetime, timezone
import logging

from app.models.location import LocationDB, LocationIn
from app.repositories.alert_repository import AlertRepository
from app.repositories.geofence_config_repository import GeofenceConfigRepository
from app.repositories.location_repository import LocationRepository
from app.repositories.device_permission_repository import DevicePermissionRepository
from app.services.alert_state_service import AlertStateService
from app.services.geofence_service import GeofenceService
from app.services.notification_service import NotificationService
from app.ws.connection_manager import ConnectionManager

logger = logging.getLogger(__name__)


class LocationProcessor:
    def __init__(
        self,
        repository: LocationRepository,
        device_permission_repository: DevicePermissionRepository,
        geofence_services: dict,
        db,
        alert_state_service: AlertStateService,
        notification_service: NotificationService,
        ws_manager: ConnectionManager,
        alert_repository: AlertRepository | None = None,
    ) -> None:
        self.repository = repository
        self.device_permission_repository = device_permission_repository
        self.geofence_services = geofence_services
        self.db = db
        self.alert_state_service = alert_state_service
        self.notification_service = notification_service
        self.ws_manager = ws_manager
        self.alert_repository = alert_repository

    def _get_geofence_service_for_device(self, device_id: str) -> GeofenceService | None:
        owner = self.device_permission_repository.get_owner(device_id)
        if not owner:
            return None
        owner_user_id = str(owner["userId"])
        if owner_user_id not in self.geofence_services:
            repo = GeofenceConfigRepository(self.db, user_id=owner_user_id)
            self.geofence_services[owner_user_id] = GeofenceService(config_repo=repo)
        return self.geofence_services[owner_user_id]

    def process(self, raw_payload: dict) -> None:
        location = LocationIn.model_validate(raw_payload)
        logger.info(f"Processing: {location.deviceId} at lat={location.lat}, lng={location.lng}")

        if self.alert_state_service.should_ignore_as_noise(location.deviceId, location.lat, location.lng):
            logger.debug(f"Ignored noise: {location.deviceId}")
            return

        self.alert_state_service.update_last_location(location.deviceId, location.lat, location.lng)

        geofence_service = self._get_geofence_service_for_device(location.deviceId)

        if geofence_service is None:
            inside_geofence = False
            distance = float("inf")
            matched_gf_id = None
            geofences = []
            gf = {}
        else:
            raw_state = geofence_service.get_state()
            geofences = raw_state.get("geofences", [])
            gf = geofences[0] if geofences else {}
            inside_geofence, distance, matched_gf_id = geofence_service.is_inside(location.lat, location.lng)

        matched_gf = next((g for g in geofences if g.get("id") == matched_gf_id), {})
        geofence_name = matched_gf.get("name") or matched_gf_id
        received_at = int(datetime.now(tz=timezone.utc).timestamp())

        logger.info(
            "Geofence: %s distance=%.2fm inside=%s matched_gf=%s",
            location.deviceId,
            distance,
            inside_geofence,
            matched_gf_id,
        )

        location_db = LocationDB(
            deviceId=location.deviceId,
            lat=location.lat,
            lng=location.lng,
            timestamp=location.timestamp,
            insideGeofence=inside_geofence,
            distanceFromCenterM=distance,
            receivedAt=received_at,
            geofenceId=matched_gf_id,
        )

        inserted = self.repository.insert_location(location_db)
        if not inserted:
            logger.debug(f"Duplicate location (not inserted): {location.deviceId}")
            return

        should_alert, event = self.alert_state_service.evaluate_alert(
            location.deviceId, inside_geofence, matched_gf_id
        )

        if should_alert:
            logger.warning(f"ALERT TRIGGERED: {location.deviceId} event={event} gf={matched_gf_id}")
            if self.alert_repository:
                self.alert_repository.insert_alert(
                    device_id=location.deviceId,
                    event=event,
                    lat=location.lat,
                    lng=location.lng,
                    timestamp=location.timestamp,
                    geofence_id=matched_gf_id,
                    geofence_name=geofence_name,
                )
            self.notification_service.send_geofence_alert(
                device_id=location.deviceId,
                lat=location.lat,
                lng=location.lng,
                timestamp=location.timestamp,
                event=event,
                geofence_id=matched_gf_id,
                geofence_name=geofence_name,
            )

        self.ws_manager.broadcast_from_thread(
            {
                "type": "location_update",
                "deviceId": location.deviceId,
                "lat": location.lat,
                "lng": location.lng,
                "timestamp": location.timestamp,
                "insideGeofence": inside_geofence,
                "geofenceId": matched_gf_id,
                "distanceFromCenterM": round(distance, 2) if distance != float("inf") else None,
                "geofenceMode": gf.get("mode", "fixed"),
                "geofenceCenterLat": gf.get("centerLat", 21.0285),
                "geofenceCenterLng": gf.get("centerLng", 105.8542),
                "geofenceRadiusM": gf.get("radiusM", 100.0),
            }
        )

        if should_alert:
            self.ws_manager.broadcast_from_thread(
                {
                    "type": "geofence_alert",
                    "deviceId": location.deviceId,
                    "lat": location.lat,
                    "lng": location.lng,
                    "timestamp": location.timestamp,
                    "event": event,
                    "geofenceId": matched_gf_id,
                }
            )
