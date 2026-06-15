from typing import List
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from app.repositories.base_repository import BaseRepository
from app.models.branch import Branch


class BranchRepository(BaseRepository[Branch]):
    def __init__(self, db: AsyncSession):
        super().__init__(Branch, db)

    async def get_by_company(self, company_id: str) -> List[Branch]:
        result = await self.db.execute(
            select(Branch)
            .where(Branch.company_id == company_id, Branch.is_active == True)
            .order_by(Branch.name)
        )
        return list(result.scalars().all())
