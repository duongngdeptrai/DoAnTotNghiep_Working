from datetime import datetime, timezone
from typing import Optional

from pydantic import BaseModel, Field, field_validator


class LocationIn(BaseModel):
    deviceId: str = Field(min_length=1)
    lat: float
    lng: float
    timestamp: int = Field(default_factory=lambda: int(datetime.now(tz=timezone.utc).timestamp()))

    @field_validator("lat")
    @classmethod
    def validate_lat(cls, value: float) -> float:
        if not -90 <= value <= 90:
            raise ValueError("lat must be in [-90, 90]")
        return value

    @field_validator("lng")
    @classmethod
    def validate_lng(cls, value: float) -> float:
        if not -180 <= value <= 180:
            raise ValueError("lng must be in [-180, 180]")
        return value


class LocationOut(BaseModel):
    deviceId: str
    lat: float
    lng: float
    timestamp: int
    insideGeofence: bool
    distanceFromCenterM: float


class LocationDB(LocationOut):
    receivedAt: int


class StatsRequest(BaseModel):
    start: int = Field(..., description="Start timestamp (Unix epoch seconds)")
    end: int = Field(..., description="End timestamp (Unix epoch seconds)")


class DailyStats(BaseModel):
    date: str  # YYYY-MM-DD
    pointCount: int
    totalDistanceM: float
    avgSpeedKmh: Optional[float]
    activeDurationSec: int


class HeatmapPoint(BaseModel):
    lat: float
    lng: float
    weight: int  # number of points at this location (for heatmap intensity)


class StatsResponse(BaseModel):
    deviceId: str
    start: int
    end: int
    totalPoints: int
    totalDistanceM: float
    activeDurationSec: int
    avgSpeedKmh: Optional[float]
    stopCount: int  # points where speed ~0
    dailyStats: list[DailyStats]
    heatmapData: list[HeatmapPoint]
    trackPath: list[dict]  # [{lat, lng, timestamp}]
