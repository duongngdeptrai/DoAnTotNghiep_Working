from datetime import datetime, timezone
import logging

from app.models.location import LocationDB, LocationIn
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
        geofence_service: GeofenceService,
        alert_state_service: AlertStateService,
        notification_service: NotificationService,
        ws_manager: ConnectionManager,
    ) -> None:
        self.repository = repository
        self.device_permission_repository = device_permission_repository
        self.geofence_service = geofence_service
        self.alert_state_service = alert_state_service
        self.notification_service = notification_service
        self.ws_manager = ws_manager

    def process(self, raw_payload: dict) -> None:
        location = LocationIn.model_validate(raw_payload)
        logger.info(f"Processing: {location.deviceId} at lat={location.lat}, lng={location.lng}")

        if not self.device_permission_repository.is_device_registered(location.deviceId):
            logger.warning("Ignored unregistered device: %s", location.deviceId)
            return

        if self.alert_state_service.should_ignore_as_noise(location.deviceId, location.lat, location.lng):
            logger.debug(f"Ignored noise: {location.deviceId}")
            return

        self.alert_state_service.update_last_location(location.deviceId, location.lat, location.lng)

        geofence_state = self.geofence_service.get_state()
        inside_geofence, distance = self.geofence_service.is_inside(location.lat, location.lng)
        received_at = int(datetime.now(tz=timezone.utc).timestamp())
        
        logger.info(
            "Geofence: %s distance=%.2fm inside=%s mode=%s center=(%s,%s)",
            location.deviceId,
            distance,
            inside_geofence,
            geofence_state["mode"],
            geofence_state["centerLat"],
            geofence_state["centerLng"],
        )

        location_db = LocationDB(
            deviceId=location.deviceId,
            lat=location.lat,
            lng=location.lng,
            timestamp=location.timestamp,
            insideGeofence=inside_geofence,
            distanceFromCenterM=distance,
            receivedAt=received_at,
        )

        inserted = self.repository.insert_location(location_db)
        if not inserted:
            logger.debug(f"Duplicate location (not inserted): {location.deviceId}")
            return

        should_alert, event = self.alert_state_service.evaluate_alert(location.deviceId, inside_geofence)
        
        if should_alert:
            logger.warning(f"ALERT TRIGGERED: {location.deviceId} event={event}")
            self.notification_service.send_geofence_alert(
                location.deviceId,
                location.lat,
                location.lng,
                location.timestamp,
                event,
            )

        self.ws_manager.broadcast_from_thread(
            {
                "type": "location_update",
                "deviceId": location.deviceId,
                "lat": location.lat,
                "lng": location.lng,
                "timestamp": location.timestamp,
                "insideGeofence": inside_geofence,
                "distanceFromCenterM": round(distance, 2),
                "geofenceMode": geofence_state["mode"],
                "geofenceCenterLat": geofence_state["centerLat"],
                "geofenceCenterLng": geofence_state["centerLng"],
                "geofenceRadiusM": geofence_state["radiusM"],
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
                }
            )
