from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession
from typing import List
from app.core.database import get_db
from app.core.security import get_current_user
from app.services.finance_service import FinanceService
from app.schemas.finance import FinanceOut, FinanceSummaryOut

router = APIRouter(prefix="/finance", tags=["Financeiro"])


@router.get("/summary", response_model=FinanceSummaryOut, summary="Receita, custo e lucro do período")
async def get_summary(
    days: int = Query(1, ge=1, le=365, description="Janela em dias (1 = hoje)"),
    db: AsyncSession = Depends(get_db),
    current_user=Depends(get_current_user),
):
    svc = FinanceService(db)
    return await svc.get_summary(current_user.company_id, days)


@router.get("", response_model=List[FinanceOut], summary="Lançamentos financeiros recentes")
async def list_finance(
    days: int = Query(30, ge=1, le=365),
    db: AsyncSession = Depends(get_db),
    current_user=Depends(get_current_user),
):
    svc = FinanceService(db)
    return await svc.list_recent(current_user.company_id, days)
