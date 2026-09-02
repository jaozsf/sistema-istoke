from sqlalchemy.ext.asyncio import AsyncSession
from fastapi import HTTPException, status
from app.core.firebase import verify_firebase_token
from app.core.security import create_access_token
from app.repositories.user_repository import UserRepository
from app.models.user import User, UserRole
from app.models.company import Company
from app.models.branch import Branch
from app.schemas.user import LoginRequest, TokenOut, UserOut


class AuthService:
    def __init__(self, db: AsyncSession):
        self.db = db
        self.user_repo = UserRepository(db)

    async def login(self, payload: LoginRequest) -> TokenOut:
        # 1. Verifica o token Firebase (aceita qualquer provedor, incl. Google)
        firebase_data = verify_firebase_token(payload.firebase_id_token)
        uid = firebase_data.get("uid")
        if not uid:
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="UID não encontrado no token.")

        # 2. Busca usuário no banco pelo firebase_uid
        user = await self.user_repo.get_by_firebase_uid(uid)
        if not user:
            # Se já existe conta com esse email (cadastrada por outro provedor
            # pelo admin), vincula o UID novo em vez de duplicar.
            email = firebase_data.get("email")
            user = await self.user_repo.get_by_email(email) if email else None
            if user:
                user.firebase_uid = uid
                await self.db.flush()
            else:
                # Auto-cadastro: primeiro login com Google/email vira dono
                # (admin) de uma empresa nova e vazia — cada login
                # desconhecido é um tenant novo, não entra em empresa alheia.
                user = await self._auto_provision(firebase_data)

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

    async def _auto_provision(self, firebase_data: dict) -> User:
        """Login desconhecido = tenant novo: cria empresa + filial próprias
        (vazias) e o usuário vira admin dela. Nunca entra em empresa de outra
        conta."""
        email = firebase_data.get("email") or f"{firebase_data['uid']}@sem-email.local"
        name  = firebase_data.get("name") or email.split("@")[0]

        company = Company(name=f"Empresa de {name}", email=email, plan="free")
        self.db.add(company)
        await self.db.flush()

        branch = Branch(name="Matriz", company_id=company.id)
        self.db.add(branch)
        await self.db.flush()

        user = User(
            firebase_uid=firebase_data["uid"],
            email=email,
            full_name=name,
            role=UserRole.admin,
            company_id=company.id,
            branch_id=branch.id,
        )
        self.db.add(user)
        await self.db.flush()
        await self.db.refresh(user)
        return user
