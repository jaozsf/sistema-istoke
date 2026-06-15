from typing import Optional, List
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from app.repositories.base_repository import BaseRepository
from app.models.user import User


class UserRepository(BaseRepository[User]):
    def __init__(self, db: AsyncSession):
        super().__init__(User, db)

    async def get_by_email(self, email: str) -> Optional[User]:
        result = await self.db.execute(select(User).where(User.email == email))
        return result.scalar_one_or_none()

    async def get_by_firebase_uid(self, uid: str) -> Optional[User]:
        result = await self.db.execute(select(User).where(User.firebase_uid == uid))
        return result.scalar_one_or_none()

    async def get_by_company(self, company_id: str) -> List[User]:
        result = await self.db.execute(
            select(User).where(User.company_id == company_id).order_by(User.full_name)
        )
        return list(result.scalars().all())

    async def get_by_branch(self, branch_id: str) -> List[User]:
        result = await self.db.execute(
            select(User).where(User.branch_id == branch_id)
        )
        return list(result.scalars().all())
