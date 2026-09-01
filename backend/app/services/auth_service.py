from sqlalchemy.ext.asyncio import AsyncSession
from fastapi import HTTPException, status
from app.core.firebase import verify_firebase_token
from app.core.security import create_access_token
from app.repositories.user_repository import UserRepository
from app.repositories.company_repository import CompanyRepository
from app.repositories.branch_repository import BranchRepository
from app.models.user import User, UserRole
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
                # Auto-cadastro: primeiro login com Google vira conta nova,
                # role mínima, vinculada à empresa padrão do sistema.
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
        """Cria conta nova (role operator) na primeira empresa ativa do sistema."""
        comp_repo   = CompanyRepository(self.db)
        branch_repo = BranchRepository(self.db)

        companies = await comp_repo.get_active()
        if not companies:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Nenhuma empresa configurada para vincular a conta.",
            )
        company = companies[0]
        branches = await branch_repo.get_by_company(company.id)
        branch = branches[0] if branches else None

        email = firebase_data.get("email") or f"{firebase_data['uid']}@sem-email.local"
        name  = firebase_data.get("name") or email.split("@")[0]

        user = User(
            firebase_uid=firebase_data["uid"],
            email=email,
            full_name=name,
            role=UserRole.operator,
            company_id=company.id,
            branch_id=branch.id if branch else None,
        )
        self.db.add(user)
        await self.db.flush()
        await self.db.refresh(user)
        return user
