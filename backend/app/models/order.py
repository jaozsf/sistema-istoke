import uuid
import enum
from datetime import datetime, timezone
from decimal import Decimal
from sqlalchemy import (
    String, Boolean, DateTime, Integer, Numeric, Text, ForeignKey, UniqueConstraint,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.core.database import Base


class OrderStatus(str, enum.Enum):
    """
    Fluxo do pedido:
      enviado      -> vendedor fechou com o cliente e mandou pra fábrica
      em_producao  -> produção aplicando arte/borda (pulado se nenhum item
                      tem personalização)
      em_separacao -> expedição separando as caixas no estoque
      conferido    -> conferência caixa a caixa bateu com o pedido
      despachado   -> carga entregue à distribuidora escolhida
      cancelado
    Guardado como String (não Enum do Postgres) pra novos estágios não
    exigirem ALTER TYPE.
    """
    enviado      = "enviado"
    em_producao  = "em_producao"
    em_separacao = "em_separacao"
    conferido    = "conferido"
    despachado   = "despachado"
    cancelado    = "cancelado"


class Order(Base):
    __tablename__ = "orders"
    __table_args__ = (UniqueConstraint("company_id", "number", name="uq_order_company_number"),)

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    # Número sequencial por empresa, o que aparece pro usuário (#0042)
    number: Mapped[int] = mapped_column(Integer, nullable=False)
    status: Mapped[str] = mapped_column(String(20), nullable=False, default=OrderStatus.enviado.value, index=True)

    company_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("companies.id", ondelete="CASCADE"), nullable=False, index=True
    )
    # Filial de onde sai o estoque
    branch_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("branches.id", ondelete="RESTRICT"), nullable=False
    )
    customer_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("customers.id", ondelete="RESTRICT"), nullable=False, index=True
    )
    seller_id: Mapped[str | None] = mapped_column(
        String(36), ForeignKey("users.id", ondelete="SET NULL"), nullable=True, index=True
    )
    # Escolhida pelo vendedor junto com o cliente
    distributor_id: Mapped[str | None] = mapped_column(
        String(36), ForeignKey("distributors.id", ondelete="SET NULL"), nullable=True
    )

    notes: Mapped[str | None] = mapped_column(Text, nullable=True)
    # Preenchidos no despacho
    invoice_number: Mapped[str | None] = mapped_column(String(50), nullable=True)  # NF
    tracking_code: Mapped[str | None] = mapped_column(String(100), nullable=True)
    # Divergência registrada na conferência (caixa amassada, faltou etc.)
    check_notes: Mapped[str | None] = mapped_column(Text, nullable=True)

    # Estoque é baixado quando o pedido sai de "enviado" (copo sai da
    # prateleira antes de arte/borda). Flag evita baixar duas vezes e diz
    # se cancelamento precisa devolver.
    stock_deducted: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)

    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc), index=True)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc), onupdate=lambda: datetime.now(timezone.utc))
    dispatched_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    items:  Mapped[list["OrderItem"]]  = relationship("OrderItem", back_populates="order", cascade="all, delete-orphan", lazy="selectin", order_by="OrderItem.position")
    events: Mapped[list["OrderEvent"]] = relationship("OrderEvent", back_populates="order", cascade="all, delete-orphan", lazy="selectin", order_by="OrderEvent.created_at")

    @property
    def needs_production(self) -> bool:
        return any(i.has_art or i.has_border for i in self.items)

    @property
    def total_boxes(self) -> int:
        return sum(i.quantity_boxes for i in self.items)

    @property
    def total_units(self) -> int:
        return sum(i.quantity_units for i in self.items)

    @property
    def checked_boxes(self) -> int:
        return sum(min(i.checked_boxes, i.quantity_boxes) for i in self.items)

    @property
    def total_amount(self) -> Decimal:
        return sum((i.unit_price * i.quantity_units for i in self.items), Decimal(0))

    @property
    def total_weight_kg(self) -> float:
        return round(sum(float(i.box_weight_kg or 0) * i.quantity_boxes for i in self.items), 3)

    def __repr__(self):
        return f"<Order #{self.number} [{self.status}]>"


class OrderItem(Base):
    __tablename__ = "order_items"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    order_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("orders.id", ondelete="CASCADE"), nullable=False, index=True
    )
    product_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("products.id", ondelete="RESTRICT"), nullable=False
    )
    position: Mapped[int] = mapped_column(Integer, default=0, nullable=False)

    # Snapshot do padrão de caixa no momento do pedido -- se o admin mudar
    # o padrão depois, pedido antigo não muda de quantidade.
    quantity_boxes: Mapped[int] = mapped_column(Integer, nullable=False)
    units_per_box: Mapped[int] = mapped_column(Integer, nullable=False)
    box_weight_kg: Mapped[Decimal | None] = mapped_column(Numeric(8, 3), nullable=True)
    unit_price: Mapped[Decimal] = mapped_column(Numeric(12, 2), nullable=False, default=0)
    product_name: Mapped[str] = mapped_column(String(255), nullable=False)
    product_sku: Mapped[str] = mapped_column(String(50), nullable=False)

    has_art: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    has_border: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    art_notes: Mapped[str | None] = mapped_column(Text, nullable=True)

    # Conferência da expedição: caixas contadas desse item
    checked_boxes: Mapped[int] = mapped_column(Integer, default=0, nullable=False)

    order: Mapped["Order"] = relationship("Order", back_populates="items")

    @property
    def quantity_units(self) -> int:
        return self.quantity_boxes * self.units_per_box

    @property
    def is_checked(self) -> bool:
        return self.checked_boxes >= self.quantity_boxes


class OrderEvent(Base):
    """Linha do tempo do pedido: quem mudou de qual etapa pra qual, e quando."""
    __tablename__ = "order_events"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    order_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("orders.id", ondelete="CASCADE"), nullable=False, index=True
    )
    from_status: Mapped[str | None] = mapped_column(String(20), nullable=True)
    to_status: Mapped[str] = mapped_column(String(20), nullable=False)
    note: Mapped[str | None] = mapped_column(Text, nullable=True)
    user_id: Mapped[str | None] = mapped_column(
        String(36), ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )
    user_name: Mapped[str | None] = mapped_column(String(255), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))

    order: Mapped["Order"] = relationship("Order", back_populates="events")
