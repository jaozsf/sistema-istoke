from datetime import datetime
from typing import List
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func
from app.repositories.base_repository import BaseRepository
from app.models.finance import Finance, FinanceType


class FinanceRepository(BaseRepository[Finance]):
    def __init__(self, db: AsyncSession):
        super().__init__(Finance, db)

    async def get_by_company_range(
        self, company_id: str, start: datetime, end: datetime, limit: int = 200
    ) -> List[Finance]:
        result = await self.db.execute(
            select(Finance)
            .where(
                Finance.company_id == company_id,
                Finance.created_at >= start,
                Finance.created_at < end,
            )
            .order_by(Finance.created_at.desc())
            .limit(limit)
        )
        return list(result.scalars().all())

    async def sum_by_type(self, company_id: str, start: datetime, end: datetime) -> dict:
        result = await self.db.execute(
            select(Finance.type, func.coalesce(func.sum(Finance.amount), 0))
            .where(
                Finance.company_id == company_id,
                Finance.created_at >= start,
                Finance.created_at < end,
            )
            .group_by(Finance.type)
        )
        totals = {t.value: 0.0 for t in FinanceType}
        for ftype, total in result.all():
            totals[ftype if isinstance(ftype, str) else ftype.value] = float(total)
        return totals
