import logging
from datetime import datetime, timezone
from typing import Literal

from fastapi import APIRouter, Depends, HTTPException, Request, status
from pydantic import BaseModel, EmailStr, Field

from app.core.auth import create_access_token, get_current_user, hash_password, verify_password
from app.models.device_config import DeviceConfigIn
from app.models.device_permission import DevicePermissionOut, DeviceRegisterIn, DeviceShareIn
from app.models.location import StatsRequest, StatsResponse
from app.services.location_processor import LocationProcessor
from app.models.user import AuthTokenOut, UserLoginIn, UserOut, UserRegisterIn
from app.repositories.device_permission_repository import DevicePermissionRepository
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
    path: list[list[float]] | None = None


def _flat_geofence_state(state: dict) -> dict:
    geofences = state.get("geofences", [])
    g = geofences[0] if geofences else {}
    return {
        "geofences": geofences,
        "mode": g.get("mode", "fixed"),
        "centerLat": g.get("centerLat", 21.0285),
        "centerLng": g.get("centerLng", 105.8542),
        "radiusM": g.get("radiusM", 100.0),
        "source": g.get("source", "fixed"),
        "updatedAt": g.get("updatedAt"),
    }


@router.post("/geofence/update")
def update_full_geofence(
    payload: GeofenceFullUpdate,
    request: Request,
    current_user: dict = Depends(get_current_user),
) -> dict:
    _require_any_owner(current_user, _permission_repo(request))
    geofence_service = request.app.state.geofence_service
    state = geofence_service.update_full_geofence(
        geofence_id=payload.geofence_id,
        mode=payload.mode,
        radius_m=payload.radius_m,
        center_lat=payload.lat,
        center_lng=payload.lng,
        path=payload.path,
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
    current_user: dict = Depends(get_current_user),
) -> dict:
    _require_any_owner(current_user, _permission_repo(request))
    geofence_service = request.app.state.geofence_service
    state = geofence_service.delete_geofence(geofence_id)
    flat = _flat_geofence_state(state)
    ws_manager.broadcast_from_thread({"type": "geofence_state_update", **flat})
    return flat


def _permission_repo(request: Request) -> DevicePermissionRepository:
    return request.app.state.device_permission_repository


def _require_device_access(device_id: str, user: dict, repo: DevicePermissionRepository) -> str:
    role = repo.get_role_for_user(device_id, user["id"])
    if not role:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Access denied")
    return role


def _require_device_owner(device_id: str, user: dict, repo: DevicePermissionRepository) -> None:
    role = _require_device_access(device_id, user, repo)
    if role != "owner":
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Owner role required")


def _require_any_device(user: dict, repo: DevicePermissionRepository) -> None:
    if not repo.get_device_ids_for_user(user["id"]):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="No device access")


def _require_any_owner(user: dict, repo: DevicePermissionRepository) -> None:
    if not repo.user_has_owner_device(user["id"]):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Owner role required")


@router.get("/health")
def health() -> dict:
    return {"status": "ok"}


@router.post("/auth/register", response_model=AuthTokenOut)
def register(payload: UserRegisterIn) -> AuthTokenOut:
    repo = UserRepository()
    password_hash = hash_password(payload.password)
    try:
        user = repo.create_user(payload.email, password_hash)
    except ValueError:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Email already exists")
    token = create_access_token(user_id=str(user["_id"]), email=user["email"])
    return AuthTokenOut(
        access_token=token,
        user=UserOut(id=str(user["_id"]), email=user["email"], createdAt=user["createdAt"]),
    )


@router.post("/auth/login", response_model=AuthTokenOut)
def login(payload: UserLoginIn) -> AuthTokenOut:
    repo = UserRepository()
    user = repo.get_by_email(payload.email)
    if not user or not verify_password(payload.password, user.get("passwordHash", "")):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid credentials")
    token = create_access_token(user_id=str(user["_id"]), email=user["email"])
    logger.info(f"Login successful for user: {user['email']} (id: {str(user['_id'])})")
    return AuthTokenOut(
        access_token=token,
        user=UserOut(id=str(user["_id"]), email=user["email"], createdAt=user["createdAt"]),
    )


@router.get("/auth/me", response_model=UserOut)
def me(current_user: dict = Depends(get_current_user)) -> UserOut:
    return UserOut(
        id=current_user["id"],
        email=current_user["email"],
        createdAt=current_user["createdAt"],
    )


@router.post("/devices", response_model=DevicePermissionOut)
def register_device(
    payload: DeviceRegisterIn,
    request: Request,
    current_user: dict = Depends(get_current_user),
) -> DevicePermissionOut:
    repo = _permission_repo(request)
    logger.info(f"Register device: deviceId={payload.deviceId} for user={current_user['id']}")
    owner = repo.get_owner(payload.deviceId)
    if owner:
        logger.info(f" -> Device already has owner: user={owner.get('userId')}")
        if str(owner.get("userId")) != current_user["id"]:
            raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Device already owned")

    result = repo.add_owner(payload.deviceId, current_user["id"])
    logger.info(f" -> Added/verified owner: deviceId={payload.deviceId}, user={current_user['id']}")
    return DevicePermissionOut(deviceId=payload.deviceId, role="owner")


@router.get("/devices", response_model=list[DevicePermissionOut])
def list_devices(
    request: Request,
    current_user: dict = Depends(get_current_user),
) -> list[DevicePermissionOut]:
    repo = _permission_repo(request)
    devices = repo.list_devices_for_user(current_user["id"])
    logger.info(f"List devices for user {current_user['id']}: found {len(devices)} devices")
    return [DevicePermissionOut(deviceId=item["deviceId"], role=item["role"]) for item in devices]


@router.delete("/devices/{device_id}")
def unregister_device(
    device_id: str,
    request: Request,
    current_user: dict = Depends(get_current_user),
) -> dict:
    repo = _permission_repo(request)
    removed = repo.remove_device(device_id, current_user["id"])
    if not removed:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Device not found or not owned")
    return {"message": "Device unregistered successfully", "deviceId": device_id}


@router.post("/devices/{device_id}/share")
def share_device(
    device_id: str,
    payload: DeviceShareIn,
    request: Request,
    current_user: dict = Depends(get_current_user),
) -> dict:
    permission_repo = _permission_repo(request)
    _require_device_owner(device_id, current_user, permission_repo)

    user_repo = UserRepository()
    target_user = user_repo.get_by_email(payload.email)
    if not target_user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")
    if str(target_user["_id"]) == current_user["id"]:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Cannot share with yourself")

    permission_repo.add_shared(device_id, str(target_user["_id"]))
    return {"message": "Shared successfully"}


@router.delete("/devices/{device_id}/share/{email}")
def unshare_device(
    device_id: str,
    email: EmailStr,
    request: Request,
    current_user: dict = Depends(get_current_user),
) -> dict:
    permission_repo = _permission_repo(request)
    _require_device_owner(device_id, current_user, permission_repo)

    user_repo = UserRepository()
    target_user = user_repo.get_by_email(str(email))
    if not target_user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")

    removed = permission_repo.remove_shared(device_id, str(target_user["_id"]))
    if not removed:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Share not found")
    return {"message": "Unshared successfully"}


@router.get("/geofence/state")
def get_geofence_state(
    request: Request,
    current_user: dict = Depends(get_current_user),
) -> dict:
    _require_any_device(current_user, _permission_repo(request))
    geofence_service = request.app.state.geofence_service
    return _flat_geofence_state(geofence_service.get_state())


@router.post("/geofence/center")
def update_geofence_center(
    payload: GeofenceCenterUpdate,
    request: Request,
    current_user: dict = Depends(get_current_user),
) -> dict:
    _require_any_owner(current_user, _permission_repo(request))
    geofence_service = request.app.state.geofence_service
    state = geofence_service.upsert_geofence(
        "default", mode="fixed", centerLat=payload.lat, centerLng=payload.lng, source="fixed"
    )
    flat = _flat_geofence_state(state)
    ws_manager.broadcast_from_thread({"type": "geofence_state_update", **flat})
    return flat


@router.post("/geofence/mode")
def set_geofence_mode(
    payload: GeofenceModeUpdate,
    request: Request,
    current_user: dict = Depends(get_current_user),
) -> dict:
    _require_any_owner(current_user, _permission_repo(request))
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
    current_user: dict = Depends(get_current_user),
) -> dict:
    _require_any_owner(current_user, _permission_repo(request))
    geofence_service = request.app.state.geofence_service
    state = geofence_service.update_path(payload.path)
    flat = _flat_geofence_state(state)
    ws_manager.broadcast_from_thread({"type": "geofence_state_update", **flat})
    return flat


@router.post("/geofence/radius")
def update_geofence_radius(
    payload: GeofenceRadiusUpdate,
    request: Request,
    current_user: dict = Depends(get_current_user),
) -> dict:
    _require_any_owner(current_user, _permission_repo(request))
    geofence_service = request.app.state.geofence_service
    state = geofence_service.upsert_geofence("default", radiusM=payload.radius_m)
    flat = _flat_geofence_state(state)
    ws_manager.broadcast_from_thread({"type": "geofence_state_update", **flat})
    return flat


@router.get("/latest/{device_id}")
def get_latest(
    device_id: str,
    request: Request,
    current_user: dict = Depends(get_current_user),
) -> dict:
    _require_device_access(device_id, current_user, _permission_repo(request))
    repo = LocationRepository()
    latest = repo.get_latest_by_device(device_id)
    if not latest:
        raise HTTPException(status_code=404, detail="No location found for this device")
    return latest


@router.get("/history/{device_id}")
def get_history(
    device_id: str,
    request: Request,
    limit: int = 100,
    current_user: dict = Depends(get_current_user),
) -> list[dict]:
    _require_device_access(device_id, current_user, _permission_repo(request))
    repo = LocationRepository()
    return repo.get_history_by_device(device_id, max(1, min(limit, 1000)))


@router.post("/devices/{device_id}/config")
def set_device_config(
    device_id: str,
    payload: DeviceConfigIn,
    request: Request,
    current_user: dict = Depends(get_current_user),
) -> dict:
    """Set or update email config for a device."""
    _require_device_owner(device_id, current_user, _permission_repo(request))
    device_config_repo = request.app.state.device_config_repository
    config = device_config_repo.upsert_config(device_id, payload.parentEmail, payload.alertEnabled)
    return config


@router.get("/devices/{device_id}/config")
def get_device_config(
    device_id: str,
    request: Request,
    current_user: dict = Depends(get_current_user),
) -> dict:
    """Get email config for a device."""
    _require_device_owner(device_id, current_user, _permission_repo(request))
    device_config_repo = request.app.state.device_config_repository
    config = device_config_repo.get_config(device_id)
    if not config:
        raise HTTPException(status_code=404, detail="No config found for this device")
    return config


@router.delete("/devices/{device_id}/config")
def delete_device_config(
    device_id: str,
    request: Request,
    current_user: dict = Depends(get_current_user),
) -> dict:
    """Delete email config for a device."""
    _require_device_owner(device_id, current_user, _permission_repo(request))
    device_config_repo = request.app.state.device_config_repository
    deleted = device_config_repo.delete_config(device_id)
    if not deleted:
        raise HTTPException(status_code=404, detail="No config found for this device")
    return {"message": "Config deleted successfully"}


@router.get("/stats/{device_id}")
def get_statistics(
    device_id: str,
    request: Request,
    start: int = None,
    end: int = None,
    current_user: dict = Depends(get_current_user),
) -> dict:
    """
    Get comprehensive statistics for a device.
    If start/end not provided, defaults to last 24 hours.
    """
    _require_device_access(device_id, current_user, _permission_repo(request))
    repo = LocationRepository()

    now = int(datetime.now(tz=timezone.utc).timestamp())
    if end is None:
        end = now
    if start is None:
        start = now - 24 * 3600

    if start > end:
        raise HTTPException(status_code=400, detail="start must be <= end")

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
    request: Request,
    start: int = None,
    end: int = None,
    interval: str = "day",
    current_user: dict = Depends(get_current_user),
) -> list[dict]:
    """
    Get aggregated statistics for a device grouped by interval (hour, day, week, year).
    """
    _require_device_access(device_id, current_user, _permission_repo(request))
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
    request: Request,
    start: int = None,
    end: int = None,
    bucket_size: float = 0.0005,
    current_user: dict = Depends(get_current_user),
) -> list[dict]:
    """
    Get heatmap data for device locations.
    Points are bucketed into grid cells for efficient rendering.
    """
    _require_device_access(device_id, current_user, _permission_repo(request))
    repo = LocationRepository()

    now = int(datetime.now(tz=timezone.utc).timestamp())
    if end is None:
        end = now
    if start is None:
        start = now - 7 * 24 * 3600

    heatmap_data = repo.get_heatmap_data(device_id, start, end, bucket_size)
    return heatmap_data
