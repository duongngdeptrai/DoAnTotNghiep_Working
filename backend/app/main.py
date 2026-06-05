import asyncio
import logging
import sys

from fastapi import FastAPI, HTTPException, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware

from app.api.routes import router as api_router
from app.core.config import get_settings
from app.core.auth import get_user_from_token
from app.db.mongo import mongo_manager
from app.repositories.device_config_repository import DeviceConfigRepository
from app.repositories.device_permission_repository import DevicePermissionRepository
from app.repositories.geofence_config_repository import GeofenceConfigRepository
from app.repositories.location_repository import LocationRepository
from app.services.alert_state_service import AlertStateService
from app.services.geofence_service import GeofenceService
from app.services.location_processor import LocationProcessor
from app.services.mqtt_service import MQTTService
from app.services.notification_service import NotificationService
from app.ws.connection_manager import ws_manager

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
    stream=sys.stdout,
)
logger = logging.getLogger(__name__)
logging.getLogger("paho").setLevel(logging.WARNING)

settings = get_settings()
app = FastAPI(title=settings.app_name)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(api_router)

logger.info(f"App: {settings.app_name}")
logger.info(f"Geofence mode: {settings.geofence_mode}")
logger.info(f"Geofence center: ({settings.geofence_center_lat}, {settings.geofence_center_lng})")
logger.info(f"Geofence radius: {settings.geofence_radius_m}m")


@app.on_event("startup")
async def on_startup() -> None:
    logger.info("=== STARTUP BEGIN ===")

    logger.info("Connecting to MongoDB...")
    mongo_manager.connect()
    logger.info(f" -> MongoDB: {settings.mongo_uri}")

    logger.info("Attaching event loop to WebSocket manager...")
    ws_manager.attach_loop(asyncio.get_running_loop())

    logger.info("Initializing services...")
    geofence_service = GeofenceService(
        config_repo=GeofenceConfigRepository(mongo_manager.db),
        center_lat=settings.geofence_center_lat,
        center_lng=settings.geofence_center_lng,
        radius_m=settings.geofence_radius_m,
        mode=settings.geofence_mode,
    )
    alert_state_service = AlertStateService(
        cooldown_sec=settings.alert_cooldown_sec,
        noise_threshold_m=settings.noise_threshold_m,
        repeat_outside=settings.alert_repeat_outside,
    )
    device_config_repository = DeviceConfigRepository(mongo_manager.db)
    device_permission_repository = DevicePermissionRepository()
    notification_service = NotificationService(settings, device_config_repository)
    repository = LocationRepository()

    # If default device email is provided via settings/.env, ensure config exists
    try:
        if settings.default_device_email:
            device_config_repository.upsert_config(
                settings.default_device_id, settings.default_device_email, True
            )
            logger.info(
                "Default device config ensured: %s -> %s",
                settings.default_device_id,
                settings.default_device_email,
            )
    except Exception:
        logger.exception("Failed to ensure default device config")

    location_processor = LocationProcessor(
        repository=repository,
        device_permission_repository=device_permission_repository,
        geofence_service=geofence_service,
        alert_state_service=alert_state_service,
        notification_service=notification_service,
        ws_manager=ws_manager,
    )

    app.state.geofence_service = geofence_service
    app.state.location_processor = location_processor
    app.state.device_config_repository = device_config_repository
    app.state.device_permission_repository = device_permission_repository

    logger.info("Starting MQTT subscriber...")
    mqtt_service = MQTTService(settings, location_processor)
    mqtt_service.start()
    logger.info(f" -> MQTT: {settings.mqtt_host}:{settings.mqtt_port}")
    logger.info(f" -> Topic: {settings.mqtt_topic}")

    app.state.mqtt_service = mqtt_service

    logger.info("=== STARTUP COMPLETE ===")
    logger.info(f"Visit: http://{settings.app_host}:{settings.app_port}/docs (Swagger)")
    logger.info(f"WebSocket: ws://{settings.app_host}:{settings.app_port}/ws")


@app.on_event("shutdown")
def on_shutdown() -> None:
    mqtt_service: MQTTService | None = getattr(app.state, "mqtt_service", None)
    if mqtt_service:
        mqtt_service.stop()

    mongo_manager.close()


@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket) -> None:
    token = websocket.query_params.get("token")
    if not token:
        await websocket.close(code=1008)
        return

    try:
        user = get_user_from_token(token)
    except HTTPException:
        await websocket.close(code=1008)
        return

    permission_repo: DevicePermissionRepository = app.state.device_permission_repository
    allowed_device_ids = permission_repo.get_device_ids_for_user(user["id"])
    owner_device_ids = permission_repo.get_owner_device_ids(user["id"])
    if not allowed_device_ids:
        await websocket.close(code=1008)
        return

    await ws_manager.connect(
        websocket,
        allowed_device_ids=allowed_device_ids,
        owner_device_ids=owner_device_ids,
    )
    try:
        while True:
            await websocket.receive_text()
    except WebSocketDisconnect:
        ws_manager.disconnect(websocket)
