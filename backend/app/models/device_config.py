from pydantic import BaseModel, EmailStr, Field


class DeviceConfigIn(BaseModel):
    parentEmail: EmailStr
    alertEnabled: bool = True


class DeviceConfigOut(BaseModel):
    deviceId: str
    parentEmail: str
    alertEnabled: bool
    createdAt: int
    updatedAt: int
