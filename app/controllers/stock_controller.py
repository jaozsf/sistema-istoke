from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession
from typing import List
from app.core.database import get_db
from app.core.security import get_current_user, require_manager, require_admin
from app.services.stock_service import StockService
from app.schemas.product_stock import MovementCreate, MovementOut, StockOut, StockAdjust

router = APIRouter(tags=["Estoque"])


# ─── Consultas de saldo ───────────────────────────────────────────────────────

@router.get("/stock/low", response_model=List[StockOut], summary="Estoques abaixo do mínimo")
async def low_stock(
    db: AsyncSession = Depends(get_db),
    current_user=Depends(get_current_user),
):
    svc = StockService(db)
    return await svc.list_low_stock(current_user.company_id)


@router.get("/branches/{branch_id}/stock", response_model=List[StockOut], summary="Estoque de uma filial")
async def branch_stock(
    branch_id: str,
    db: AsyncSession = Depends(get_db),
    current_user=Depends(get_current_user),
):
    svc = StockService(db)
    return await svc.list_by_branch(branch_id)


@router.get(
    "/branches/{branch_id}/stock/{product_id}",
    response_model=StockOut,
    summary="Saldo de um produto em uma filial",
)
async def product_branch_stock(
    branch_id: str,
    product_id: str,
    db: AsyncSession = Depends(get_db),
    current_user=Depends(get_current_user),
):
    svc = StockService(db)
    stock = await svc.get_stock(product_id, branch_id)
    if not stock:
        from fastapi import HTTPException
        raise HTTPException(status_code=404, detail="Saldo não encontrado.")
    return stock


# ─── Movimentações ────────────────────────────────────────────────────────────

@router.get("/movements", response_model=List[MovementOut], summary="Movimentações recentes")
async def list_movements(
    limit: int = Query(50, ge=1, le=200),
    db: AsyncSession = Depends(get_db),
    current_user=Depends(get_current_user),
):
    svc = StockService(db)
    return await svc.list_movements(current_user.company_id, limit)


@router.post("/movements", response_model=MovementOut, status_code=201, summary="Registrar movimentação")
async def register_movement(
    data: MovementCreate,
    db: AsyncSession = Depends(get_db),
    current_user=Depends(get_current_user),
):
    """
    Tipos aceitos:
    - **entrada**: adiciona ao estoque
    - **saida**: subtrai do estoque (valida saldo)
    - **transfer**: saída de uma filial + entrada em outra
    - **ajuste**: define quantidade exata (admin)
    """
    svc = StockService(db)
    return await svc.register_movement(data, current_user.company_id, current_user.id)


# ─── Ajuste direto (admin) ────────────────────────────────────────────────────

@router.put(
    "/branches/{branch_id}/stock/{product_id}/adjust",
    response_model=StockOut,
    summary="Ajuste direto de quantidade (admin)",
)
async def adjust_stock(
    branch_id: str,
    product_id: str,
    data: StockAdjust,
    db: AsyncSession = Depends(get_db),
    current_user=Depends(require_admin),
):
    svc = StockService(db)
    return await svc.adjust_stock(product_id, branch_id, data, current_user.company_id, current_user.id)
