from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from app.core.database import get_db
from app.services.auth_service import AuthService
from app.schemas.user import LoginRequest, TokenOut

router = APIRouter(prefix="/auth", tags=["Auth"])


@router.post("/login", response_model=TokenOut, summary="Login via Firebase ID Token")
async def login(payload: LoginRequest, db: AsyncSession = Depends(get_db)):
    """
    Recebe o idToken emitido pelo Firebase Auth no Flutter.
    Valida, busca o usuário no banco e retorna um JWT interno.
    """
    service = AuthService(db)
    return await service.login(payload)
