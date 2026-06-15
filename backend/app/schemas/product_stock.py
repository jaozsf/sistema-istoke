from pydantic import BaseModel, Field
from typing import Optional
from datetime import datetime
from decimal import Decimal


# ─── Product ──────────────────────────────────────────────────────────────────

class ProductCreate(BaseModel):
    sku: str
    name: str
    description: Optional[str] = None
    category: Optional[str] = None
    unit: str = "unid"
    sale_price: Decimal = Field(ge=0)
    cost_price: Decimal = Field(ge=0)
    min_stock: int = Field(ge=0, default=0)


class ProductUpdate(BaseModel):
    name: Optional[str] = None
    description: Optional[str] = None
    category: Optional[str] = None
    unit: Optional[str] = None
    sale_price: Optional[Decimal] = None
    cost_price: Optional[Decimal] = None
    min_stock: Optional[int] = None
    is_active: Optional[bool] = None


class ProductOut(BaseModel):
    id: str
    sku: str
    name: str
    description: Optional[str]
    category: Optional[str]
    unit: str
    sale_price: Decimal
    cost_price: Decimal
    min_stock: int
    margin_percent: float
    qr_code: Optional[str]
    is_active: bool
    company_id: str
    created_at: datetime

    model_config = {"from_attributes": True}


# ─── Stock ────────────────────────────────────────────────────────────────────

class StockOut(BaseModel):
    id: str
    product_id: str
    branch_id: str
    quantity: int
    min_quantity: int
    is_low: bool
    updated_at: datetime

    model_config = {"from_attributes": True}


class StockAdjust(BaseModel):
    """Ajuste direto de quantidade (admin)."""
    quantity: int = Field(ge=0)
    min_quantity: Optional[int] = Field(ge=0, default=None)


# ─── Movement ─────────────────────────────────────────────────────────────────

class MovementCreate(BaseModel):
    type: str                          # "entrada" | "saida" | "ajuste" | "transfer"
    quantity: int = Field(gt=0)
    product_id: str
    branch_id: str
    dest_branch_id: Optional[str] = None   # apenas para "transfer"
    notes: Optional[str] = None


class MovementOut(BaseModel):
    id: str
    type: str
    quantity: int
    notes: Optional[str]
    product_id: str
    branch_id: str
    user_id: Optional[str]
    dest_branch_id: Optional[str]
    created_at: datetime

    model_config = {"from_attributes": True}
