from typing import Literal

from fastapi import APIRouter, HTTPException, Request
from pydantic import BaseModel, EmailStr, Field

from app.models.device_config import DeviceConfigIn, DeviceConfigOut
from app.repositories.location_repository import LocationRepository
from app.ws.connection_manager import ws_manager

router = APIRouter()


class GeofenceModeUpdate(BaseModel):
    mode: Literal["fixed", "mobile"]


class GeofenceCenterUpdate(BaseModel):
    lat: float = Field(ge=-90, le=90)
    lng: float = Field(ge=-180, le=180)


@router.get("/health")
def health() -> dict:
    return {"status": "ok"}


@router.get("/geofence/state")
def get_geofence_state(request: Request) -> dict:
    geofence_service = request.app.state.geofence_service
    return geofence_service.get_state()


@router.post("/geofence/mode")
def set_geofence_mode(payload: GeofenceModeUpdate, request: Request) -> dict:
    geofence_service = request.app.state.geofence_service
    if payload.mode == "fixed":
        state = geofence_service.set_fixed_mode()
    else:
        state = geofence_service.set_mobile_mode()

    ws_manager.broadcast_from_thread({"type": "geofence_state_update", **state})
    return state


@router.post("/geofence/center")
def update_geofence_center(payload: GeofenceCenterUpdate, request: Request) -> dict:
    geofence_service = request.app.state.geofence_service
    state = geofence_service.update_mobile_center(payload.lat, payload.lng)
    ws_manager.broadcast_from_thread({"type": "geofence_state_update", **state})
    return state


@router.get("/latest/{device_id}")
def get_latest(device_id: str) -> dict:
    repo = LocationRepository()
    latest = repo.get_latest_by_device(device_id)
    if not latest:
        raise HTTPException(status_code=404, detail="No location found for this device")
    return latest


@router.get("/history/{device_id}")
def get_history(device_id: str, limit: int = 100) -> list[dict]:
    repo = LocationRepository()
    return repo.get_history_by_device(device_id, max(1, min(limit, 1000)))


@router.post("/devices/{device_id}/config")
def set_device_config(device_id: str, payload: DeviceConfigIn, request: Request) -> dict:
    """Set or update email config for a device."""
    device_config_repo = request.app.state.device_config_repository
    config = device_config_repo.upsert_config(device_id, payload.parentEmail, payload.alertEnabled)
    return config


@router.get("/devices/{device_id}/config")
def get_device_config(device_id: str, request: Request) -> dict:
    """Get email config for a device."""
    device_config_repo = request.app.state.device_config_repository
    config = device_config_repo.get_config(device_id)
    if not config:
        raise HTTPException(status_code=404, detail="No config found for this device")
    return config


@router.delete("/devices/{device_id}/config")
def delete_device_config(device_id: str, request: Request) -> dict:
    """Delete email config for a device."""
    device_config_repo = request.app.state.device_config_repository
    deleted = device_config_repo.delete_config(device_id)
    if not deleted:
        raise HTTPException(status_code=404, detail="No config found for this device")
    return {"message": "Config deleted successfully"}
