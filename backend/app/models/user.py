import uuid
from datetime import datetime, timezone
from sqlalchemy import String, Boolean, DateTime, ForeignKey, Enum as SAEnum
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.core.database import Base
import enum


class UserRole(str, enum.Enum):
    admin    = "admin"
    manager  = "manager"
    operator = "operator"
    # Setores do fluxo de pedido (vendedor -> produção -> expedição).
    # Postgres: valores novos entram via ALTER TYPE no startup/migração 0003.
    seller     = "seller"
    production = "production"
    shipping   = "shipping"


class User(Base):
    __tablename__ = "users"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    # Nulo até o convidado logar pela primeira vez (admin cadastra por
    # email antes de saber o UID do Firebase). No login, se o email bater
    # com um usuário sem firebase_uid, ele é vinculado nessa hora.
    firebase_uid: Mapped[str | None] = mapped_column(String(128), unique=True, nullable=True, index=True)
    email: Mapped[str] = mapped_column(String(255), unique=True, nullable=False, index=True)
    full_name: Mapped[str] = mapped_column(String(255), nullable=False)
    role: Mapped[str] = mapped_column(
        SAEnum(UserRole, name="user_role"),
        nullable=False,
        default=UserRole.operator,
    )
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)

    # Multi-tenant: usuário pertence a uma empresa
    company_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("companies.id", ondelete="CASCADE"), nullable=False, index=True
    )
    # Opcional: usuário associado a uma filial específica
    branch_id: Mapped[str | None] = mapped_column(
        String(36), ForeignKey("branches.id", ondelete="SET NULL"), nullable=True
    )

    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc), onupdate=lambda: datetime.now(timezone.utc))

    # Relacionamentos
    company: Mapped["Company"] = relationship("Company", back_populates="users")
    branch:  Mapped["Branch | None"] = relationship("Branch", back_populates="users")
    logs:    Mapped[list["Log"]] = relationship("Log", back_populates="user", cascade="all, delete-orphan")

    def __repr__(self):
        return f"<User {self.email} [{self.role}]>"
