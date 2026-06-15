from typing import Optional, List
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from app.repositories.base_repository import BaseRepository
from app.models.stock import Stock


class StockRepository(BaseRepository[Stock]):
    def __init__(self, db: AsyncSession):
        super().__init__(Stock, db)

    async def get_by_product_branch(self, product_id: str, branch_id: str) -> Optional[Stock]:
        result = await self.db.execute(
            select(Stock).where(Stock.product_id == product_id, Stock.branch_id == branch_id)
        )
        return result.scalar_one_or_none()

    async def get_by_branch(self, branch_id: str) -> List[Stock]:
        result = await self.db.execute(
            select(Stock).where(Stock.branch_id == branch_id)
        )
        return list(result.scalars().all())

    async def get_by_product(self, product_id: str) -> List[Stock]:
        result = await self.db.execute(
            select(Stock).where(Stock.product_id == product_id)
        )
        return list(result.scalars().all())

    async def get_low_stock(self, company_id: str) -> List[Stock]:
        """Retorna todos os estoques abaixo do mínimo para a empresa."""
        from sqlalchemy import join
        from app.models.product import Product
        from app.models.branch import Branch
        result = await self.db.execute(
            select(Stock)
            .join(Product, Stock.product_id == Product.id)
            .join(Branch, Stock.branch_id == Branch.id)
            .where(
                Product.company_id == company_id,
                Stock.quantity <= Stock.min_quantity,
            )
        )
        return list(result.scalars().all())

    async def get_or_create(self, product_id: str, branch_id: str, min_quantity: int = 0) -> Stock:
        stock = await self.get_by_product_branch(product_id, branch_id)
        if not stock:
            stock = Stock(product_id=product_id, branch_id=branch_id, quantity=0, min_quantity=min_quantity)
            self.db.add(stock)
            await self.db.flush()
            await self.db.refresh(stock)
        return stock
