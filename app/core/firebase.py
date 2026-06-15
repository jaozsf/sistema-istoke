import firebase_admin
from firebase_admin import credentials, auth
from fastapi import HTTPException, status
from app.core.config import settings
import os

_firebase_app = None


def init_firebase():
    global _firebase_app
    if _firebase_app is not None:
        return _firebase_app

    cred_path = settings.FIREBASE_CREDENTIALS_PATH
    if not os.path.exists(cred_path):
        raise RuntimeError(
            f"Firebase credentials não encontrado em: {cred_path}\n"
            "Baixe o arquivo em: Firebase Console → Configurações → Contas de serviço"
        )

    cred = credentials.Certificate(cred_path)
    _firebase_app = firebase_admin.initialize_app(cred)
    return _firebase_app


def verify_firebase_token(id_token: str) -> dict:
    """
    Verifica o token JWT emitido pelo Firebase Auth.
    Retorna o payload decodificado com uid, email, etc.
    """
    try:
        decoded = auth.verify_id_token(id_token)
        return decoded
    except auth.ExpiredIdTokenError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token Firebase expirado. Faça login novamente.",
        )
    except auth.InvalidIdTokenError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token Firebase inválido.",
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Erro ao verificar token Firebase: {str(e)}",
        )


def get_firebase_user(uid: str) -> dict:
    """Busca dados do usuário no Firebase Auth pelo UID."""
    try:
        user = auth.get_user(uid)
        return {
            "uid": user.uid,
            "email": user.email,
            "display_name": user.display_name,
            "email_verified": user.email_verified,
            "disabled": user.disabled,
        }
    except auth.UserNotFoundError:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Usuário não encontrado no Firebase.",
        )
