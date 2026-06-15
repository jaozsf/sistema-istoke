from fastapi import HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from app.repositories.stock_repository import StockRepository
from app.repositories.movement_repository import MovementRepository
from app.repositories.product_repository import ProductRepository
from app.repositories.branch_repository import BranchRepository
from app.repositories.log_repository import LogRepository
from app.models.movement import Movement, MovementType
from app.schemas.product_stock import MovementCreate, StockAdjust


class StockService:
    def __init__(self, db: AsyncSession):
        self.db = db
        self.stock_repo = MovementRepository(db)
        self.sRepo = StockRepository(db)
        self.prod_repo = ProductRepository(db)
        self.branch_repo = BranchRepository(db)
        self.log_repo = LogRepository(db)

    # ── Consultas ─────────────────────────────────────────────────────────────

    async def get_stock(self, product_id: str, branch_id: str):
        return await self.sRepo.get_by_product_branch(product_id, branch_id)

    async def list_by_branch(self, branch_id: str):
        return await self.sRepo.get_by_branch(branch_id)

    async def list_low_stock(self, company_id: str):
        return await self.sRepo.get_low_stock(company_id)

    async def list_movements(self, company_id: str, limit: int = 50):
        from app.repositories.movement_repository import MovementRepository
        repo = MovementRepository(self.db)
        return await repo.get_recent_by_company(company_id, limit)

    # ── Movimentação principal ─────────────────────────────────────────────────

    async def register_movement(
        self, data: MovementCreate, company_id: str, user_id: str
    ) -> Movement:
        # Valida produto pertence à empresa
        product = await self.prod_repo.get_by_id(data.product_id)
        if not product or product.company_id != company_id:
            raise HTTPException(status_code=404, detail="Produto não encontrado.")

        # Valida filial pertence à empresa
        branch = await self.branch_repo.get_by_id(data.branch_id)
        if not branch or branch.company_id != company_id:
            raise HTTPException(status_code=404, detail="Filial não encontrada.")

        mov_type = MovementType(data.type)

        if mov_type == MovementType.entrada:
            await self._entrada(data.product_id, data.branch_id, data.quantity, product.min_stock)

        elif mov_type == MovementType.saida:
            await self._saida(data.product_id, data.branch_id, data.quantity, product.min_stock)

        elif mov_type == MovementType.transfer:
            if not data.dest_branch_id:
                raise HTTPException(status_code=400, detail="dest_branch_id obrigatório para transferência.")
            dest = await self.branch_repo.get_by_id(data.dest_branch_id)
            if not dest or dest.company_id != company_id:
                raise HTTPException(status_code=404, detail="Filial de destino não encontrada.")
            await self._saida(data.product_id, data.branch_id, data.quantity, product.min_stock)
            await self._entrada(data.product_id, data.dest_branch_id, data.quantity, product.min_stock)

        elif mov_type == MovementType.ajuste:
            stock = await self.sRepo.get_or_create(data.product_id, data.branch_id, product.min_stock)
            stock.quantity = data.quantity
            await self.db.flush()

        # Salva movimento
        movement = Movement(
            type=mov_type,
            quantity=data.quantity,
            product_id=data.product_id,
            branch_id=data.branch_id,
            dest_branch_id=data.dest_branch_id,
            user_id=user_id,
            notes=data.notes,
        )
        self.db.add(movement)
        await self.db.flush()
        await self.db.refresh(movement)

        await self.log_repo.record(
            action=f"stock.{data.type}", user_id=user_id, company_id=company_id,
            branch_id=data.branch_id, entity="movement", entity_id=movement.id,
            detail={"product_id": data.product_id, "quantity": data.quantity},
        )
        return movement

    # ── Ajuste direto (admin) ──────────────────────────────────────────────────

    async def adjust_stock(
        self, product_id: str, branch_id: str, data: StockAdjust, company_id: str, user_id: str
    ):
        product = await self.prod_repo.get_by_id(product_id)
        if not product or product.company_id != company_id:
            raise HTTPException(status_code=404, detail="Produto não encontrado.")

        stock = await self.sRepo.get_or_create(product_id, branch_id, product.min_stock)
        stock.quantity = data.quantity
        if data.min_quantity is not None:
            stock.min_quantity = data.min_quantity
        await self.db.flush()
        await self.db.refresh(stock)

        await self.log_repo.record(
            action="stock.adjust", user_id=user_id, company_id=company_id,
            branch_id=branch_id, entity="stock", entity_id=stock.id,
            detail={"quantity": data.quantity},
        )
        return stock

    # ── Helpers internos ──────────────────────────────────────────────────────

    async def _entrada(self, product_id: str, branch_id: str, qty: int, min_qty: int):
        stock = await self.sRepo.get_or_create(product_id, branch_id, min_qty)
        stock.quantity += qty
        await self.db.flush()

    async def _saida(self, product_id: str, branch_id: str, qty: int, min_qty: int):
        stock = await self.sRepo.get_or_create(product_id, branch_id, min_qty)
        if stock.quantity < qty:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail=f"Estoque insuficiente. Disponível: {stock.quantity}, solicitado: {qty}.",
            )
        stock.quantity -= qty
        await self.db.flush()
