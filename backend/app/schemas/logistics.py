from pydantic import BaseModel, Field
from typing import Optional, List, Literal
from datetime import datetime
from decimal import Decimal


# ─── Padrão de caixa ──────────────────────────────────────────────────────────

class BoxStandardIn(BaseModel):
    units_per_box: int = Field(gt=0, le=100000)
    box_type: Optional[str] = Field(default=None, max_length=100)
    length_cm: Optional[Decimal] = Field(default=None, ge=0)
    width_cm:  Optional[Decimal] = Field(default=None, ge=0)
    height_cm: Optional[Decimal] = Field(default=None, ge=0)
    weight_kg: Optional[Decimal] = Field(default=None, ge=0)
    notes: Optional[str] = None


class BoxStandardOut(BaseModel):
    id: str
    product_id: str
    units_per_box: int
    box_type: Optional[str]
    length_cm: Optional[Decimal]
    width_cm: Optional[Decimal]
    height_cm: Optional[Decimal]
    weight_kg: Optional[Decimal]
    notes: Optional[str]
    updated_at: datetime

    model_config = {"from_attributes": True}


# ─── Distribuidora ────────────────────────────────────────────────────────────

class DistributorIn(BaseModel):
    name: str = Field(min_length=1, max_length=255)
    cnpj: Optional[str] = Field(default=None, max_length=18)
    contact_name: Optional[str] = None
    phone: Optional[str] = Field(default=None, max_length=20)
    email: Optional[str] = None
    regions: Optional[str] = None
    notes: Optional[str] = None
    is_active: bool = True


class DistributorOut(BaseModel):
    id: str
    name: str
    cnpj: Optional[str]
    contact_name: Optional[str]
    phone: Optional[str]
    email: Optional[str]
    regions: Optional[str]
    notes: Optional[str]
    is_active: bool
    created_at: datetime

    model_config = {"from_attributes": True}


# ─── Cliente ──────────────────────────────────────────────────────────────────

class CustomerIn(BaseModel):
    name: str = Field(min_length=1, max_length=255)
    document: Optional[str] = Field(default=None, max_length=18)
    phone: Optional[str] = Field(default=None, max_length=20)
    email: Optional[str] = None
    city: Optional[str] = Field(default=None, max_length=100)
    state: Optional[str] = Field(default=None, max_length=2)
    address: Optional[str] = None


class CustomerOut(BaseModel):
    id: str
    name: str
    document: Optional[str]
    phone: Optional[str]
    email: Optional[str]
    city: Optional[str]
    state: Optional[str]
    address: Optional[str]
    seller_id: Optional[str]
    is_active: bool
    created_at: datetime

    model_config = {"from_attributes": True}


# ─── Pedido ───────────────────────────────────────────────────────────────────

OrderStatusLiteral = Literal["enviado", "em_producao", "em_separacao", "conferido", "despachado", "cancelado"]


class OrderItemIn(BaseModel):
    product_id: str
    quantity_boxes: int = Field(gt=0, le=100000)
    has_art: bool = False
    has_border: bool = False
    art_notes: Optional[str] = None


class OrderCreate(BaseModel):
    customer_id: str
    distributor_id: Optional[str] = None
    branch_id: Optional[str] = None   # padrão: filial de quem cria
    notes: Optional[str] = None
    items: List[OrderItemIn] = Field(min_length=1)


class OrderUpdate(BaseModel):
    """Vendedor/gerente troca distribuidora ou observação antes do despacho."""
    distributor_id: Optional[str] = None
    notes: Optional[str] = None


class OrderTransition(BaseModel):
    to_status: OrderStatusLiteral
    note: Optional[str] = None
    invoice_number: Optional[str] = Field(default=None, max_length=50)
    tracking_code: Optional[str] = Field(default=None, max_length=100)


class ItemCheck(BaseModel):
    checked_boxes: int = Field(ge=0)


class OrderItemOut(BaseModel):
    id: str
    product_id: str
    product_name: str
    product_sku: str
    quantity_boxes: int
    units_per_box: int
    quantity_units: int
    box_weight_kg: Optional[Decimal]
    unit_price: Decimal
    has_art: bool
    has_border: bool
    art_notes: Optional[str]
    checked_boxes: int
    is_checked: bool

    model_config = {"from_attributes": True}


class OrderEventOut(BaseModel):
    id: str
    from_status: Optional[str]
    to_status: str
    note: Optional[str]
    user_id: Optional[str]
    user_name: Optional[str]
    created_at: datetime

    model_config = {"from_attributes": True}


class OrderOut(BaseModel):
    id: str
    number: int
    status: str
    branch_id: str
    customer_id: str
    customer_name: Optional[str] = None
    customer_city: Optional[str] = None
    seller_id: Optional[str]
    seller_name: Optional[str] = None
    distributor_id: Optional[str]
    distributor_name: Optional[str] = None
    notes: Optional[str]
    invoice_number: Optional[str]
    tracking_code: Optional[str]
    check_notes: Optional[str]
    stock_deducted: bool
    needs_production: bool
    total_boxes: int
    total_units: int
    checked_boxes: int
    total_amount: Decimal
    total_weight_kg: float
    created_at: datetime
    updated_at: datetime
    dispatched_at: Optional[datetime]
    items: List[OrderItemOut]
    events: List[OrderEventOut]
    # Próximas etapas que QUEM PEDIU pode acionar -- o app só mostra botão
    # do que o backend aceitaria, sem duplicar a regra no Flutter.
    allowed_transitions: List[str] = []

    model_config = {"from_attributes": True}


class OrderSummaryOut(BaseModel):
    counts: dict[str, int]
    open_total: int
    dispatched_today: int
