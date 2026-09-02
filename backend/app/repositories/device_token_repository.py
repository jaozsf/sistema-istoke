from typing import List, Optional
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from app.repositories.base_repository import BaseRepository
from app.models.device_token import DeviceToken


class DeviceTokenRepository(BaseRepository[DeviceToken]):
    def __init__(self, db: AsyncSession):
        super().__init__(DeviceToken, db)

    async def get_by_token(self, token: str) -> Optional[DeviceToken]:
        result = await self.db.execute(select(DeviceToken).where(DeviceToken.token == token))
        return result.scalar_one_or_none()

    async def upsert(self, user_id: str, token: str, platform: str) -> DeviceToken:
        existing = await self.get_by_token(token)
        if existing:
            existing.user_id = user_id
            existing.platform = platform
            await self.db.flush()
            return existing
        device = DeviceToken(user_id=user_id, token=token, platform=platform)
        self.db.add(device)
        await self.db.flush()
        return device

    async def delete_by_token(self, token: str) -> None:
        existing = await self.get_by_token(token)
        if existing:
            await self.db.delete(existing)
            await self.db.flush()

    async def get_tokens_for_users(self, user_ids: List[str]) -> List[str]:
        if not user_ids:
            return []
        result = await self.db.execute(
            select(DeviceToken.token).where(DeviceToken.user_id.in_(user_ids))
        )
        return [row[0] for row in result.all()]
