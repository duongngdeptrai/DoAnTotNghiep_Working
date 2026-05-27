from typing import Literal

from pydantic import BaseModel, EmailStr, Field


class DeviceRegisterIn(BaseModel):
    deviceId: str = Field(min_length=1)


class DeviceShareIn(BaseModel):
    email: EmailStr


class DevicePermissionOut(BaseModel):
    deviceId: str
    role: Literal["owner", "shared"]
