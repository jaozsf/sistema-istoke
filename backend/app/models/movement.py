import uuid
from datetime import datetime, timezone
from sqlalchemy import String, DateTime, Integer, Text, ForeignKey, Enum as SAEnum
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.core.database import Base
import enum


class MovementType(str, enum.Enum):
    entrada  = "entrada"
    saida    = "saida"
    ajuste   = "ajuste"
    transfer = "transfer"


class Movement(Base):
    __tablename__ = "movements"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    type: Mapped[str] = mapped_column(
        SAEnum(MovementType, name="movement_type"), nullable=False
    )
    quantity: Mapped[int] = mapped_column(Integer, nullable=False)
    notes: Mapped[str | None] = mapped_column(Text, nullable=True)

    # Referências
    product_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("products.id", ondelete="CASCADE"), nullable=False, index=True
    )
    branch_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("branches.id", ondelete="CASCADE"), nullable=False, index=True
    )
    user_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )
    # Para transferências: filial de destino
    dest_branch_id: Mapped[str | None] = mapped_column(
        String(36), ForeignKey("branches.id", ondelete="SET NULL"), nullable=True
    )

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc), index=True
    )

    # Relacionamentos
    product:     Mapped["Product"]       = relationship("Product", back_populates="movements")
    branch:      Mapped["Branch"]        = relationship("Branch",  back_populates="movements", foreign_keys=[branch_id])
    user:        Mapped["User | None"]   = relationship("User")

    def __repr__(self):
        return f"<Movement {self.type} qty={self.quantity} product={self.product_id}>"
