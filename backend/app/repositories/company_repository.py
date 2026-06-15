from typing import Optional, List
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from app.repositories.base_repository import BaseRepository
from app.models.company import Company


class CompanyRepository(BaseRepository[Company]):
    def __init__(self, db: AsyncSession):
        super().__init__(Company, db)

    async def get_by_cnpj(self, cnpj: str) -> Optional[Company]:
        result = await self.db.execute(select(Company).where(Company.cnpj == cnpj))
        return result.scalar_one_or_none()

    async def get_active(self) -> List[Company]:
        result = await self.db.execute(
            select(Company).where(Company.is_active == True).order_by(Company.name)
        )
        return list(result.scalars().all())
