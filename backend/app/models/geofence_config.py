from datetime import datetime, timezone
from typing import Optional

from pydantic import BaseModel, Field, field_validator


class GeofenceConfigIn(BaseModel):
    """Input model for creating/updating geofence configuration."""
    name: str = Field(min_length=1, max_length=100)
    center_lat: float = Field(..., ge=-90, le=90)
    center_lng: float = Field(..., ge=-180, le=180)
    radius_m: float = Field(..., gt=0)
    device_id: Optional[str] = Field(None, min_length=1)  # None means global/default
    is_active: bool = True

    @field_validator("radius_m")
    @classmethod
    def validate_radius(cls, v: float) -> float:
        if v <= 0:
            raise ValueError("radius must be positive")
        return v


class GeofenceConfigOut(BaseModel):
    """Output model for geofence configuration."""
    name: str
    center_lat: float
    center_lng: float
    radius_m: float
    device_id: Optional[str]
    is_active: bool
    created_at: int
    updated_at: int


class GeofenceConfigDB(GeofenceConfigOut):
    """Database model for geofence configuration."""
    pass
