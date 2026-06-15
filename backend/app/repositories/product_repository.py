from typing import Optional, List
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from app.repositories.base_repository import BaseRepository
from app.models.product import Product


class ProductRepository(BaseRepository[Product]):
    def __init__(self, db: AsyncSession):
        super().__init__(Product, db)

    async def get_by_company(self, company_id: str, skip: int = 0, limit: int = 100) -> List[Product]:
        result = await self.db.execute(
            select(Product)
            .where(Product.company_id == company_id, Product.is_active == True)
            .order_by(Product.name)
            .offset(skip).limit(limit)
        )
        return list(result.scalars().all())

    async def get_by_sku(self, sku: str, company_id: str) -> Optional[Product]:
        result = await self.db.execute(
            select(Product).where(Product.sku == sku, Product.company_id == company_id)
        )
        return result.scalar_one_or_none()

    async def get_by_qr(self, qr_code: str) -> Optional[Product]:
        result = await self.db.execute(
            select(Product).where(Product.qr_code == qr_code)
        )
        return result.scalar_one_or_none()

    async def search(self, company_id: str, q: str) -> List[Product]:
        from sqlalchemy import or_
        term = f"%{q}%"
        result = await self.db.execute(
            select(Product).where(
                Product.company_id == company_id,
                or_(Product.name.ilike(term), Product.sku.ilike(term), Product.category.ilike(term))
            ).limit(50)
        )
        return list(result.scalars().all())
