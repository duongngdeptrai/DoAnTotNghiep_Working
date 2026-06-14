import logging
from datetime import datetime, timezone
from typing import Literal

from fastapi import APIRouter, HTTPException, Request, status
from pydantic import BaseModel, EmailStr, Field

from app.core.auth import hash_password, verify_password
from app.core.config import get_settings
from app.models.device_config import DeviceConfigIn
from app.models.device_permission import DevicePermissionOut, DeviceRegisterIn, DeviceShareIn
from app.models.user import UserLoginIn, UserOut, UserRegisterIn
from app.repositories.location_repository import LocationRepository
from app.repositories.user_repository import UserRepository
from app.ws.connection_manager import ws_manager

logger = logging.getLogger(__name__)
router = APIRouter()


class GeofenceModeUpdate(BaseModel):
    mode: Literal["fixed", "mobile"]


class GeofenceCenterUpdate(BaseModel):
    lat: float = Field(ge=-90, le=90)
    lng: float = Field(ge=-180, le=180)


class GeofenceRadiusUpdate(BaseModel):
    radius_m: float = Field(gt=0)


class GeofencePathUpdate(BaseModel):
    path: list[list[float]]


class GeofenceFullUpdate(BaseModel):
    geofence_id: str = "default"
    name: str | None = None
    mode: Literal["fixed", "mobile"]
    radius_m: float = Field(gt=0)
    lat: float | None = Field(None, ge=-90, le=90)
    lng: float | None = Field(None, ge=-180, le=180)
    path: list | None = None  # accepts [[lat,lng],...] or [{"lat":...,"lng":...},...]


def _flat_geofence_state(state: dict) -> dict:
    geofences = state.get("geofences", [])
    # Luôn dùng vùng "default" cho global mode/center/radius.
    # geofences[0] không đáng tin vì user có thể đã tạo vùng tùy chỉnh trước.
    g = next((x for x in geofences if x.get("id") == "default"), geofences[0] if geofences else {})
    return {
        "geofences": geofences,
        "mode": g.get("mode", "fixed"),
        "centerLat": g.get("centerLat", 21.0285),
        "centerLng": g.get("centerLng", 105.8542),
        "radiusM": g.get("radiusM", 100.0),
        "source": g.get("source", "fixed"),
        "updatedAt": g.get("updatedAt"),
        "name": g.get("name"),
    }


@router.post("/geofence/update")
def update_full_geofence(
    payload: GeofenceFullUpdate,
    request: Request,
) -> dict:
    geofence_service = request.app.state.geofence_service
    # Normalize path to [[lat, lng], ...] for internal storage
    normalized_path = None
    if payload.path is not None:
        normalized_path = []
        for p in payload.path:
            if isinstance(p, list) and len(p) >= 2:
                normalized_path.append([float(p[0]), float(p[1])])
            elif isinstance(p, dict):
                normalized_path.append([float(p.get("lat", 0)), float(p.get("lng", 0))])

    state = geofence_service.update_full_geofence(
        geofence_id=payload.geofence_id,
        mode=payload.mode,
        radius_m=payload.radius_m,
        center_lat=payload.lat,
        center_lng=payload.lng,
        path=normalized_path,
    )
    if payload.name:
        geofence_service.upsert_geofence(payload.geofence_id, name=payload.name)
        state = geofence_service.get_state()

    flat = _flat_geofence_state(state)
    ws_manager.broadcast_from_thread({"type": "geofence_state_update", **flat})
    return flat


@router.delete("/geofence/{geofence_id}")
def delete_geofence(
    geofence_id: str,
    request: Request,
) -> dict:
    geofence_service = request.app.state.geofence_service
    state = geofence_service.delete_geofence(geofence_id)
    flat = _flat_geofence_state(state)
    ws_manager.broadcast_from_thread({"type": "geofence_state_update", **flat})
    return flat


@router.get("/health")
def health() -> dict:
    return {"status": "ok"}


@router.post("/auth/register", response_model=UserOut)
def register(payload: UserRegisterIn) -> UserOut:
    repo = UserRepository()
    password_hash = hash_password(payload.password)
    try:
        user = repo.create_user(payload.email, password_hash)
    except ValueError:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Email already exists")
    logger.info(f"User registered: {user['email']} (id: {str(user['_id'])})")
    return UserOut(id=str(user["_id"]), email=user["email"], createdAt=user["createdAt"])


@router.post("/auth/login", response_model=UserOut)
def login(payload: UserLoginIn) -> UserOut:
    repo = UserRepository()
    user = repo.get_by_email(payload.email)
    if not user or not verify_password(payload.password, user.get("passwordHash", "")):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid credentials")
    logger.info(f"Login successful for user: {user['email']} (id: {str(user['_id'])})")
    return UserOut(id=str(user["_id"]), email=user["email"], createdAt=user["createdAt"])


@router.get("/devices", response_model=list[DevicePermissionOut])
def list_devices(
    request: Request,
) -> list[DevicePermissionOut]:
    return [
        DevicePermissionOut(deviceId="child_01", role="owner"),
        DevicePermissionOut(deviceId="child_02", role="owner"),
    ]


@router.post("/devices", response_model=DevicePermissionOut)
def register_device(
    payload: DeviceRegisterIn,
    request: Request,
) -> DevicePermissionOut:
    return DevicePermissionOut(deviceId=payload.deviceId, role="owner")


@router.delete("/devices/{device_id}")
def unregister_device(
    device_id: str,
    request: Request,
) -> dict:
    return {"message": "Device unregistered successfully", "deviceId": device_id}


@router.post("/devices/{device_id}/share")
def share_device(
    device_id: str,
    payload: DeviceShareIn,
    request: Request,
) -> dict:
    return {"message": "Shared successfully"}


@router.delete("/devices/{device_id}/share/{email}")
def unshare_device(
    device_id: str,
    email: EmailStr,
    request: Request,
) -> dict:
    return {"message": "Unshared successfully"}


@router.get("/geofence/state")
def get_geofence_state(
    request: Request,
) -> dict:
    geofence_service = request.app.state.geofence_service
    return _flat_geofence_state(geofence_service.get_state())


@router.post("/geofence/center")
def update_geofence_center(
    payload: GeofenceCenterUpdate,
    request: Request,
) -> dict:
    geofence_service = request.app.state.geofence_service
    state = geofence_service.upsert_geofence(
        "default", centerLat=payload.lat, centerLng=payload.lng
    )
    flat = _flat_geofence_state(state)
    ws_manager.broadcast_from_thread({"type": "geofence_state_update", **flat})
    return flat


@router.post("/geofence/mode")
def set_geofence_mode(
    payload: GeofenceModeUpdate,
    request: Request,
) -> dict:
    geofence_service = request.app.state.geofence_service
    if payload.mode == "fixed":
        state = geofence_service.set_fixed_mode()
    else:
        state = geofence_service.set_mobile_mode()

    flat = _flat_geofence_state(state)
    ws_manager.broadcast_from_thread({"type": "geofence_state_update", **flat})
    return flat


@router.post("/geofence/path")
def update_geofence_path(
    payload: GeofencePathUpdate,
    request: Request,
) -> dict:
    geofence_service = request.app.state.geofence_service
    state = geofence_service.update_path(payload.path)
    flat = _flat_geofence_state(state)
    ws_manager.broadcast_from_thread({"type": "geofence_state_update", **flat})
    return flat


@router.post("/geofence/radius")
def update_geofence_radius(
    payload: GeofenceRadiusUpdate,
    request: Request,
) -> dict:
    geofence_service = request.app.state.geofence_service
    state = geofence_service.upsert_geofence("default", radiusM=payload.radius_m)
    flat = _flat_geofence_state(state)
    ws_manager.broadcast_from_thread({"type": "geofence_state_update", **flat})
    return flat


@router.get("/latest/{device_id}")
def get_latest(
    device_id: str,
) -> dict:
    repo = LocationRepository()
    latest = repo.get_latest_by_device(device_id)
    if not latest:
        settings = get_settings()
        return {
            "deviceId": device_id,
            "lat": settings.geofence_center_lat,
            "lng": settings.geofence_center_lng,
            "timestamp": 0,
            "insideGeofence": False,
            "distanceFromCenterM": 0.0,
        }
    return latest


@router.get("/history/{device_id}")
def get_history(
    device_id: str,
    limit: int = 100,
) -> list[dict]:
    repo = LocationRepository()
    return repo.get_history_by_device(device_id, max(1, min(limit, 1000)))


@router.post("/devices/{device_id}/config")
def set_device_config(
    device_id: str,
    payload: DeviceConfigIn,
    request: Request,
) -> dict:
    """Set or update email config for a device."""
    device_config_repo = request.app.state.device_config_repository
    config = device_config_repo.upsert_config(device_id, payload.parentEmail, payload.alertEnabled)
    return config


@router.get("/devices/{device_id}/config")
def get_device_config(
    device_id: str,
    request: Request,
) -> dict:
    """Get email config for a device."""
    device_config_repo = request.app.state.device_config_repository
    config = device_config_repo.get_config(device_id)
    if not config:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="No config found for this device")
    return config


@router.delete("/devices/{device_id}/config")
def delete_device_config(
    device_id: str,
    request: Request,
) -> dict:
    """Delete email config for a device."""
    device_config_repo = request.app.state.device_config_repository
    deleted = device_config_repo.delete_config(device_id)
    if not deleted:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="No config found for this device")
    return {"message": "Config deleted successfully"}


@router.get("/stats/{device_id}")
def get_statistics(
    device_id: str,
    start: int = None,
    end: int = None,
) -> dict:
    """
    Get comprehensive statistics for a device.
    If start/end not provided, defaults to last 24 hours.
    """
    repo = LocationRepository()

    now = int(datetime.now(tz=timezone.utc).timestamp())
    if end is None:
        end = now
    if start is None:
        start = now - 24 * 3600

    if start > end:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="start must be <= end")

    stats = repo.get_statistics(device_id, start, end)
    track_path = repo.get_track_path(device_id, start, end)

    return {
        "deviceId": device_id,
        "start": start,
        "end": end,
        **stats,
        "trackPath": track_path,
    }


@router.get("/stats/{device_id}/aggregated")
def get_aggregated_statistics(
    device_id: str,
    start: int = None,
    end: int = None,
    interval: str = "day",
) -> list[dict]:
    """Get aggregated statistics for a device grouped by interval (hour, day, week, year)."""
    repo = LocationRepository()

    now = int(datetime.now(tz=timezone.utc).timestamp())
    if end is None:
        end = now
    if start is None:
        start = now - 7 * 24 * 3600

    return repo.get_aggregated_stats(device_id, start, end, interval)


@router.get("/stats/{device_id}/heatmap")
def get_heatmap(
    device_id: str,
    start: int = None,
    end: int = None,
    bucket_size: float = 0.0005,
) -> list[dict]:
    """Get heatmap data for device locations."""
    repo = LocationRepository()

    now = int(datetime.now(tz=timezone.utc).timestamp())
    if end is None:
        end = now
    if start is None:
        start = now - 7 * 24 * 3600

    heatmap_data = repo.get_heatmap_data(device_id, start, end, bucket_size)
    return heatmap_data
