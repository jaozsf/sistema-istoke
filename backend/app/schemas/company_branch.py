from pydantic import BaseModel
from typing import Optional
from datetime import datetime


# ─── Company ──────────────────────────────────────────────────────────────────

class CompanyCreate(BaseModel):
    name: str
    cnpj: Optional[str] = None
    email: Optional[str] = None
    phone: Optional[str] = None
    address: Optional[str] = None
    plan: str = "free"


class CompanyUpdate(BaseModel):
    name: Optional[str] = None
    cnpj: Optional[str] = None
    email: Optional[str] = None
    phone: Optional[str] = None
    address: Optional[str] = None
    plan: Optional[str] = None
    is_active: Optional[bool] = None


class CompanyOut(BaseModel):
    id: str
    name: str
    cnpj: Optional[str]
    email: Optional[str]
    phone: Optional[str]
    plan: str
    is_active: bool
    created_at: datetime

    model_config = {"from_attributes": True}


# ─── Branch ───────────────────────────────────────────────────────────────────

class BranchCreate(BaseModel):
    name: str
    city: Optional[str] = None
    state: Optional[str] = None
    address: Optional[str] = None
    phone: Optional[str] = None


class BranchUpdate(BaseModel):
    name: Optional[str] = None
    city: Optional[str] = None
    state: Optional[str] = None
    address: Optional[str] = None
    phone: Optional[str] = None
    is_active: Optional[bool] = None


class BranchOut(BaseModel):
    id: str
    name: str
    city: Optional[str]
    state: Optional[str]
    address: Optional[str]
    phone: Optional[str]
    is_active: bool
    company_id: str
    created_at: datetime

    model_config = {"from_attributes": True}
