from sqlalchemy.ext.asyncio import AsyncSession
from fastapi import HTTPException, status
from app.core.firebase import verify_firebase_token
from app.core.security import create_access_token
from app.repositories.user_repository import UserRepository
from app.schemas.user import LoginRequest, TokenOut, UserOut


class AuthService:
    def __init__(self, db: AsyncSession):
        self.db = db
        self.user_repo = UserRepository(db)

    async def login(self, payload: LoginRequest) -> TokenOut:
        # 1. Verifica o token Firebase
        firebase_data = verify_firebase_token(payload.firebase_id_token)
        uid = firebase_data.get("uid")
        if not uid:
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="UID não encontrado no token.")

        # 2. Busca usuário no banco pelo firebase_uid
        user = await self.user_repo.get_by_firebase_uid(uid)
        if not user:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Usuário não cadastrado no sistema. Contate o administrador.",
            )
        if not user.is_active:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Conta desativada.")

        # 3. Gera JWT interno com sub=user.id, role e company_id
        token = create_access_token({
            "sub": user.id,
            "role": user.role,
            "company_id": user.company_id,
            "branch_id": user.branch_id,
        })

        return TokenOut(access_token=token, user=UserOut.model_validate(user))
