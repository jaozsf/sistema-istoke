from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from pydantic import BaseModel
from app.core.database import get_db
from app.core.security import get_current_user
from app.ai.assistant import ask_assistant

router = APIRouter(prefix="/ai", tags=["IA"])


class AskRequest(BaseModel):
    question: str


class AskResponse(BaseModel):
    answer: str


@router.post("/ask", response_model=AskResponse, summary="Perguntar ao assistente IA")
async def ask(
    payload: AskRequest,
    db: AsyncSession = Depends(get_db),
    current_user=Depends(get_current_user),
):
    """
    Envia uma pergunta ao assistente IA com contexto real da empresa do usuário.
    Exemplo: "Qual filial tem mais estoque parado?"
    """
    answer = await ask_assistant(payload.question, current_user.company_id, db)
    return AskResponse(answer=answer)
