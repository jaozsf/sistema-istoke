from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from typing import List
from app.core.database import get_db
from app.core.security import get_current_user, require_admin, require_manager
from app.services.user_service import UserService
from pydantic import BaseModel, Field
from app.schemas.user import UserCreate, UserUpdate, UserOut

router = APIRouter(prefix="/users", tags=["Usuários"])


class UpdateMyName(BaseModel):
    full_name: str = Field(min_length=1, max_length=255)


@router.get("/me", response_model=UserOut, summary="Dados do usuário logado")
async def me(current_user=Depends(get_current_user)):
    return current_user


@router.patch("/me", response_model=UserOut, summary="Atualiza o próprio nome")
async def update_my_name(
    data: UpdateMyName,
    db: AsyncSession = Depends(get_db),
    current_user=Depends(get_current_user),
):
    # Auto-servido: qualquer usuário logado pode atualizar só o PRÓPRIO
    # nome (nunca role/empresa/filial) -- pedido no primeiro login pra
    # quem entra por email/senha (sem nome no token, ao contrário do Google).
    current_user.full_name = data.full_name
    await db.flush()
    await db.refresh(current_user)
    return current_user


@router.get("", response_model=List[UserOut], summary="Listar usuários da empresa")
async def list_users(
    db: AsyncSession = Depends(get_db),
    current_user=Depends(require_manager),
):
    svc = UserService(db)
    return await svc.list_by_company(current_user.company_id)


@router.post("", response_model=UserOut, status_code=201, summary="Cadastrar usuário")
async def create_user(
    data: UserCreate,
    db: AsyncSession = Depends(get_db),
    current_user=Depends(require_admin),
):
    # company_id/branch_id nunca vêm do cliente -- sempre a empresa/filial
    # de quem tá criando. Sem isso um admin podia criar usuário em empresa
    # alheia só passando outro company_id no corpo da requisição.
    data.company_id = current_user.company_id
    if not data.branch_id:
        data.branch_id = current_user.branch_id
    svc = UserService(db)
    return await svc.create(data, current_user.id)


@router.get("/{user_id}", response_model=UserOut)
async def get_user(
    user_id: str,
    db: AsyncSession = Depends(get_db),
    current_user=Depends(require_manager),
):
    svc = UserService(db)
    return await svc.get(user_id, current_user.company_id)


@router.patch("/{user_id}", response_model=UserOut)
async def update_user(
    user_id: str,
    data: UserUpdate,
    db: AsyncSession = Depends(get_db),
    current_user=Depends(require_admin),
):
    svc = UserService(db)
    return await svc.update(user_id, data, current_user.company_id, current_user.id)


@router.delete("/{user_id}", status_code=204, summary="Desativar usuário")
async def deactivate_user(
    user_id: str,
    db: AsyncSession = Depends(get_db),
    current_user=Depends(require_admin),
):
    svc = UserService(db)
    await svc.deactivate(user_id, current_user.company_id, current_user.id)
