import uuid
import enum
from datetime import datetime, timezone
from sqlalchemy import String, DateTime, ForeignKey, Enum as SAEnum
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.core.database import Base


class DevicePlatform(str, enum.Enum):
    android = "android"
    ios     = "ios"
    web     = "web"


class DeviceToken(Base):
    """
    Token FCM de um dispositivo/navegador logado. Um usuário pode ter
    vários (celular + web), e um token só existe uma vez -- se o mesmo
    token aparecer vinculado a outro usuário (relogin no mesmo aparelho
    com conta diferente), o upsert realoca o dono.
    """
    __tablename__ = "device_tokens"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    token: Mapped[str] = mapped_column(String(255), unique=True, nullable=False, index=True)
    platform: Mapped[str] = mapped_column(SAEnum(DevicePlatform, name="device_platform"), nullable=False)

    user_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )

    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc), onupdate=lambda: datetime.now(timezone.utc))

    user: Mapped["User"] = relationship("User")

    def __repr__(self):
        return f"<DeviceToken user={self.user_id} platform={self.platform}>"
