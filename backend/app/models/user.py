from pydantic import BaseModel, EmailStr, Field


class UserRegisterIn(BaseModel):
    email: EmailStr
    password: str = Field(min_length=6, max_length=128)


class UserLoginIn(BaseModel):
    email: EmailStr
    password: str = Field(min_length=6, max_length=128)


class UserOut(BaseModel):
    id: str
    email: EmailStr
    createdAt: int


class AuthTokenOut(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user: UserOut
