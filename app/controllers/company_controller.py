from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from typing import List
from app.core.database import get_db
from app.core.security import require_admin, get_current_user
from app.services.company_service import CompanyService, BranchService
from app.schemas.company_branch import (
    CompanyCreate, CompanyUpdate, CompanyOut,
    BranchCreate, BranchUpdate, BranchOut,
)

router = APIRouter(tags=["Empresas & Filiais"])


# ─── Empresas ─────────────────────────────────────────────────────────────────

@router.get("/companies", response_model=List[CompanyOut], summary="Listar empresas")
async def list_companies(
    db: AsyncSession = Depends(get_db),
    current_user=Depends(require_admin),
):
    svc = CompanyService(db)
    return await svc.list()


@router.post("/companies", response_model=CompanyOut, status_code=201, summary="Criar empresa")
async def create_company(
    data: CompanyCreate,
    db: AsyncSession = Depends(get_db),
    current_user=Depends(require_admin),
):
    svc = CompanyService(db)
    return await svc.create(data, current_user.id)


@router.get("/companies/{company_id}", response_model=CompanyOut)
async def get_company(
    company_id: str,
    db: AsyncSession = Depends(get_db),
    current_user=Depends(get_current_user),
):
    svc = CompanyService(db)
    return await svc.get(company_id)


@router.patch("/companies/{company_id}", response_model=CompanyOut)
async def update_company(
    company_id: str,
    data: CompanyUpdate,
    db: AsyncSession = Depends(get_db),
    current_user=Depends(require_admin),
):
    svc = CompanyService(db)
    return await svc.update(company_id, data, current_user.id)


@router.delete("/companies/{company_id}", status_code=204)
async def delete_company(
    company_id: str,
    db: AsyncSession = Depends(get_db),
    current_user=Depends(require_admin),
):
    svc = CompanyService(db)
    await svc.delete(company_id, current_user.id)


# ─── Filiais ──────────────────────────────────────────────────────────────────

@router.get("/companies/{company_id}/branches", response_model=List[BranchOut])
async def list_branches(
    company_id: str,
    db: AsyncSession = Depends(get_db),
    current_user=Depends(get_current_user),
):
    svc = BranchService(db)
    return await svc.list(company_id)


@router.post("/companies/{company_id}/branches", response_model=BranchOut, status_code=201)
async def create_branch(
    company_id: str,
    data: BranchCreate,
    db: AsyncSession = Depends(get_db),
    current_user=Depends(require_admin),
):
    svc = BranchService(db)
    return await svc.create(data, company_id, current_user.id)


@router.patch("/companies/{company_id}/branches/{branch_id}", response_model=BranchOut)
async def update_branch(
    company_id: str,
    branch_id: str,
    data: BranchUpdate,
    db: AsyncSession = Depends(get_db),
    current_user=Depends(require_admin),
):
    svc = BranchService(db)
    return await svc.update(branch_id, data, company_id, current_user.id)


@router.delete("/companies/{company_id}/branches/{branch_id}", status_code=204)
async def delete_branch(
    company_id: str,
    branch_id: str,
    db: AsyncSession = Depends(get_db),
    current_user=Depends(require_admin),
):
    svc = BranchService(db)
    await svc.delete(branch_id, company_id, current_user.id)
