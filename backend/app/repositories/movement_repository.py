from typing import List, Optional
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func
from datetime import datetime
from app.repositories.base_repository import BaseRepository
from app.models.movement import Movement


class MovementRepository(BaseRepository[Movement]):
    def __init__(self, db: AsyncSession):
        super().__init__(Movement, db)

    async def get_by_branch(self, branch_id: str, limit: int = 50) -> List[Movement]:
        result = await self.db.execute(
            select(Movement)
            .where(Movement.branch_id == branch_id)
            .order_by(Movement.created_at.desc())
            .limit(limit)
        )
        return list(result.scalars().all())

    async def get_by_product(self, product_id: str, limit: int = 50) -> List[Movement]:
        result = await self.db.execute(
            select(Movement)
            .where(Movement.product_id == product_id)
            .order_by(Movement.created_at.desc())
            .limit(limit)
        )
        return list(result.scalars().all())

    async def get_recent_by_company(self, company_id: str, limit: int = 50) -> List[Movement]:
        from app.models.product import Product
        result = await self.db.execute(
            select(Movement)
            .join(Product, Movement.product_id == Product.id)
            .where(Product.company_id == company_id)
            .order_by(Movement.created_at.desc())
            .limit(limit)
        )
        return list(result.scalars().all())

    async def get_between_dates(
        self, company_id: str, start: datetime, end: datetime
    ) -> List[Movement]:
        from app.models.product import Product
        result = await self.db.execute(
            select(Movement)
            .join(Product, Movement.product_id == Product.id)
            .where(
                Product.company_id == company_id,
                Movement.created_at >= start,
                Movement.created_at <= end,
            )
            .order_by(Movement.created_at.desc())
        )
        return list(result.scalars().all())
