from pydantic import BaseModel, EmailStr, Field
from typing import Optional
from datetime import datetime
from app.models.user import UserRole


class UserCreate(BaseModel):
    firebase_uid: str
    email: EmailStr
    full_name: str
    role: UserRole = UserRole.operator
    company_id: str
    branch_id: Optional[str] = None


class UserUpdate(BaseModel):
    full_name: Optional[str] = None
    role: Optional[UserRole] = None
    branch_id: Optional[str] = None
    is_active: Optional[bool] = None


class UserOut(BaseModel):
    id: str
    firebase_uid: str
    email: str
    full_name: str
    role: UserRole
    is_active: bool
    company_id: str
    branch_id: Optional[str]
    created_at: datetime

    model_config = {"from_attributes": True}


class LoginRequest(BaseModel):
    """Recebe o ID token do Firebase Auth emitido pelo Flutter."""
    firebase_id_token: str


class TokenOut(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user: UserOut
