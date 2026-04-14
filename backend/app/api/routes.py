from fastapi import APIRouter, HTTPException

from app.repositories.location_repository import LocationRepository

router = APIRouter()


@router.get("/health")
def health() -> dict:
    return {"status": "ok"}


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
