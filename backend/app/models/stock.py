import uuid
from datetime import datetime, timezone
from sqlalchemy import String, DateTime, Integer, ForeignKey, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.core.database import Base


class Stock(Base):
    """
    Saldo atual de um produto em uma filial.
    Constraint unique: um registro por (product_id, branch_id).
    """
    __tablename__ = "stocks"
    __table_args__ = (
        UniqueConstraint("product_id", "branch_id", name="uq_stock_product_branch"),
    )

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    quantity: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    min_quantity: Mapped[int] = mapped_column(Integer, nullable=False, default=0)

    product_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("products.id", ondelete="CASCADE"), nullable=False, index=True
    )
    branch_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("branches.id", ondelete="CASCADE"), nullable=False, index=True
    )

    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        onupdate=lambda: datetime.now(timezone.utc),
    )

    # Relacionamentos
    product: Mapped["Product"] = relationship("Product", back_populates="stocks")
    branch:  Mapped["Branch"]  = relationship("Branch",  back_populates="stocks")

    @property
    def is_low(self) -> bool:
        return self.quantity <= self.min_quantity

    def __repr__(self):
        return f"<Stock product={self.product_id} branch={self.branch_id} qty={self.quantity}>"
