from typing import List
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from app.repositories.base_repository import BaseRepository
from app.models.log import Log


class LogRepository(BaseRepository[Log]):
    def __init__(self, db: AsyncSession):
        super().__init__(Log, db)

    async def get_by_company(self, company_id: str, limit: int = 100) -> List[Log]:
        result = await self.db.execute(
            select(Log)
            .where(Log.company_id == company_id)
            .order_by(Log.created_at.desc())
            .limit(limit)
        )
        return list(result.scalars().all())

    async def get_by_user(self, user_id: str, limit: int = 50) -> List[Log]:
        result = await self.db.execute(
            select(Log).where(Log.user_id == user_id).order_by(Log.created_at.desc()).limit(limit)
        )
        return list(result.scalars().all())

    async def record(
        self,
        action: str,
        user_id: str | None = None,
        company_id: str | None = None,
        branch_id: str | None = None,
        entity: str | None = None,
        entity_id: str | None = None,
        detail: dict | None = None,
        ip_address: str | None = None,
    ) -> Log:
        log = Log(
            action=action,
            user_id=user_id,
            company_id=company_id,
            branch_id=branch_id,
            entity=entity,
            entity_id=entity_id,
            detail=detail,
            ip_address=ip_address,
        )
        self.db.add(log)
        await self.db.flush()
        return log
