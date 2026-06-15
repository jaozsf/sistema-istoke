from fastapi import HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from app.repositories.user_repository import UserRepository
from app.repositories.log_repository import LogRepository
from app.models.user import User
from app.schemas.user import UserCreate, UserUpdate


class UserService:
    def __init__(self, db: AsyncSession):
        self.db = db
        self.repo = UserRepository(db)
        self.log_repo = LogRepository(db)

    async def list_by_company(self, company_id: str):
        return await self.repo.get_by_company(company_id)

    async def get(self, user_id: str, company_id: str) -> User:
        user = await self.repo.get_by_id(user_id)
        if not user or user.company_id != company_id:
            raise HTTPException(status_code=404, detail="Usuário não encontrado.")
        return user

    async def create(self, data: UserCreate, actor_id: str) -> User:
        if await self.repo.get_by_email(data.email):
            raise HTTPException(status_code=409, detail="E-mail já cadastrado.")
        if await self.repo.get_by_firebase_uid(data.firebase_uid):
            raise HTTPException(status_code=409, detail="UID Firebase já vinculado.")

        user = User(**data.model_dump())
        user = await self.repo.create(user)
        await self.log_repo.record(
            action="user.create", user_id=actor_id, company_id=data.company_id,
            entity="user", entity_id=user.id, detail={"email": user.email, "role": user.role},
        )
        return user

    async def update(self, user_id: str, data: UserUpdate, company_id: str, actor_id: str) -> User:
        user = await self.get(user_id, company_id)
        user = await self.repo.update(user, data.model_dump(exclude_none=True))
        await self.log_repo.record(
            action="user.update", user_id=actor_id, company_id=company_id,
            entity="user", entity_id=user_id,
        )
        return user

    async def deactivate(self, user_id: str, company_id: str, actor_id: str) -> User:
        user = await self.get(user_id, company_id)
        user.is_active = False
        await self.db.flush()
        await self.log_repo.record(
            action="user.deactivate", user_id=actor_id, company_id=company_id,
            entity="user", entity_id=user_id,
        )
        return user
