import uuid
from datetime import datetime, timezone
from sqlalchemy import String, Boolean, DateTime, Text, Numeric, ForeignKey
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.core.database import Base
from decimal import Decimal


class Product(Base):
    __tablename__ = "products"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    sku: Mapped[str] = mapped_column(String(50), nullable=False, index=True)
    name: Mapped[str] = mapped_column(String(255), nullable=False)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    category: Mapped[str | None] = mapped_column(String(100), nullable=True)
    unit: Mapped[str] = mapped_column(String(20), default="unid", nullable=False)

    # Preços
    sale_price: Mapped[Decimal] = mapped_column(Numeric(12, 2), nullable=False, default=0)
    cost_price: Mapped[Decimal] = mapped_column(Numeric(12, 2), nullable=False, default=0)

    # QR Code — armazena o payload (SKU + ID) como string
    qr_code: Mapped[str | None] = mapped_column(String(500), nullable=True)

    # Estoque mínimo global (pode ser sobrescrito por filial)
    min_stock: Mapped[int] = mapped_column(default=0, nullable=False)

    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)

    # Multi-tenant
    company_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("companies.id", ondelete="CASCADE"), nullable=False, index=True
    )

    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc), onupdate=lambda: datetime.now(timezone.utc))

    # Relacionamentos
    company:   Mapped["Company"]        = relationship("Company", back_populates="products")
    stocks:    Mapped[list["Stock"]]    = relationship("Stock",    back_populates="product", cascade="all, delete-orphan")
    movements: Mapped[list["Movement"]] = relationship("Movement", back_populates="product", cascade="all, delete-orphan")

    @property
    def margin_percent(self) -> float:
        if self.sale_price and self.sale_price > 0:
            return round(float((self.sale_price - self.cost_price) / self.sale_price * 100), 2)
        return 0.0

    def __repr__(self):
        return f"<Product {self.sku} - {self.name}>"
