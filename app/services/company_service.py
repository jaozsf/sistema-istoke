from fastapi import HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from app.repositories.company_repository import CompanyRepository
from app.repositories.branch_repository import BranchRepository
from app.repositories.log_repository import LogRepository
from app.models.company import Company
from app.models.branch import Branch
from app.schemas.company_branch import (
    CompanyCreate, CompanyUpdate,
    BranchCreate, BranchUpdate,
)


# ─── Company Service ──────────────────────────────────────────────────────────

class CompanyService:
    def __init__(self, db: AsyncSession):
        self.db = db
        self.repo = CompanyRepository(db)
        self.log_repo = LogRepository(db)

    async def list(self):
        return await self.repo.get_active()

    async def get(self, company_id: str) -> Company:
        company = await self.repo.get_by_id(company_id)
        if not company:
            raise HTTPException(status_code=404, detail="Empresa não encontrada.")
        return company

    async def create(self, data: CompanyCreate, user_id: str) -> Company:
        if data.cnpj:
            existing = await self.repo.get_by_cnpj(data.cnpj)
            if existing:
                raise HTTPException(status_code=409, detail="CNPJ já cadastrado.")
        company = Company(**data.model_dump())
        company = await self.repo.create(company)
        await self.log_repo.record(
            action="company.create", user_id=user_id, company_id=company.id,
            entity="company", entity_id=company.id, detail={"name": company.name},
        )
        return company

    async def update(self, company_id: str, data: CompanyUpdate, user_id: str) -> Company:
        company = await self.get(company_id)
        company = await self.repo.update(company, data.model_dump(exclude_none=True))
        await self.log_repo.record(
            action="company.update", user_id=user_id, company_id=company_id,
            entity="company", entity_id=company_id,
        )
        return company

    async def delete(self, company_id: str, user_id: str) -> None:
        company = await self.get(company_id)
        await self.repo.delete(company)
        await self.log_repo.record(
            action="company.delete", user_id=user_id, company_id=company_id,
        )


# ─── Branch Service ───────────────────────────────────────────────────────────

class BranchService:
    def __init__(self, db: AsyncSession):
        self.db = db
        self.repo = BranchRepository(db)
        self.log_repo = LogRepository(db)

    async def list(self, company_id: str):
        return await self.repo.get_by_company(company_id)

    async def get(self, branch_id: str, company_id: str) -> Branch:
        branch = await self.repo.get_by_id(branch_id)
        if not branch or branch.company_id != company_id:
            raise HTTPException(status_code=404, detail="Filial não encontrada.")
        return branch

    async def create(self, data: BranchCreate, company_id: str, user_id: str) -> Branch:
        branch = Branch(**data.model_dump(), company_id=company_id)
        branch = await self.repo.create(branch)
        await self.log_repo.record(
            action="branch.create", user_id=user_id, company_id=company_id,
            entity="branch", entity_id=branch.id, detail={"name": branch.name},
        )
        return branch

    async def update(self, branch_id: str, data: BranchUpdate, company_id: str, user_id: str) -> Branch:
        branch = await self.get(branch_id, company_id)
        branch = await self.repo.update(branch, data.model_dump(exclude_none=True))
        await self.log_repo.record(
            action="branch.update", user_id=user_id, company_id=company_id,
            entity="branch", entity_id=branch_id,
        )
        return branch

    async def delete(self, branch_id: str, company_id: str, user_id: str) -> None:
        branch = await self.get(branch_id, company_id)
        await self.repo.delete(branch)
        await self.log_repo.record(
            action="branch.delete", user_id=user_id, company_id=company_id,
            entity="branch", entity_id=branch_id,
        )
