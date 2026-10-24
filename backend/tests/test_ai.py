"""
Testes da camada de IA (sem chamar a internet: o httpx é substituído).
Rode com: pytest tests/ -v
"""
import httpx
import pytest
from app.ai import llm
from app.core.config import settings


class _FakeClient:
    def __init__(self, response: httpx.Response, calls: list):
        self._response = response
        self._calls = calls

    async def __aenter__(self):
        return self

    async def __aexit__(self, *exc):
        return False

    async def post(self, url, json=None, headers=None):
        self._calls.append({"url": url, "json": json, "headers": headers})
        return self._response


def _patch(monkeypatch, status: int, payload: dict, calls: list):
    resp = httpx.Response(status, json=payload, request=httpx.Request("POST", "https://x"))
    monkeypatch.setattr(llm.httpx, "AsyncClient", lambda **kw: _FakeClient(resp, calls))


@pytest.fixture(autouse=True)
def _keys(monkeypatch):
    for k in ("GROQ_API_KEY", "GEMINI_API_KEY", "ANTHROPIC_API_KEY", "AI_MODEL"):
        monkeypatch.setattr(settings, k, "")
    monkeypatch.setattr(settings, "AI_PROVIDER", "auto")


@pytest.mark.asyncio
async def test_sem_chave_explica_como_configurar():
    with pytest.raises(llm.LLMError, match="GROQ_API_KEY"):
        await llm.complete("sistema", "pergunta")


@pytest.mark.asyncio
async def test_groq_e_o_padrao_e_le_a_resposta(monkeypatch):
    monkeypatch.setattr(settings, "GROQ_API_KEY", "gsk_teste")
    monkeypatch.setattr(settings, "GEMINI_API_KEY", "gem_teste")
    calls = []
    _patch(monkeypatch, 200, {"choices": [{"message": {"content": "1. Abra Pedidos"}}]}, calls)

    assert await llm.complete("sistema", "como faço pedido?") == "1. Abra Pedidos"
    assert calls[0]["url"] == "https://api.groq.com/openai/v1/chat/completions"
    assert calls[0]["json"]["model"] == "openai/gpt-oss-120b"
    assert calls[0]["json"]["reasoning_effort"] == "low"
    assert calls[0]["headers"]["Authorization"] == "Bearer gsk_teste"


@pytest.mark.asyncio
async def test_gemini_quando_so_ele_tem_chave(monkeypatch):
    monkeypatch.setattr(settings, "GEMINI_API_KEY", "gem_teste")
    calls = []
    _patch(monkeypatch, 200, {"choices": [{"message": {"content": "ok"}}]}, calls)
    await llm.complete("sistema", "oi")
    assert "generativelanguage.googleapis.com" in calls[0]["url"]
    assert "reasoning_effort" not in calls[0]["json"]


@pytest.mark.asyncio
async def test_limite_gratis_vira_mensagem_amigavel(monkeypatch):
    monkeypatch.setattr(settings, "GROQ_API_KEY", "gsk_teste")
    _patch(monkeypatch, 429, {"error": {"message": "rate limit"}}, [])
    with pytest.raises(llm.LLMError, match="Limite gratuito"):
        await llm.complete("sistema", "oi")


# ── Contexto por setor ────────────────────────────────────────────────────────

import uuid  # noqa: E402
import pytest_asyncio  # noqa: E402
from app.ai.assistant import build_company_context, ask_assistant  # noqa: E402
from app.models.company import Company  # noqa: E402
from app.models.branch import Branch  # noqa: E402
from app.models.user import User, UserRole  # noqa: E402
from app.models.product import Product  # noqa: E402
from tests.test_products import setup_db, db  # noqa: E402,F401 -- fixtures compartilhadas


@pytest_asyncio.fixture
async def company(db):
    cid, bid = str(uuid.uuid4()), str(uuid.uuid4())
    users = {
        r: User(id=str(uuid.uuid4()), email=f"{r}@x.com", full_name=r.title(), role=getattr(UserRole, r),
                company_id=cid, branch_id=bid)
        for r in ("admin", "seller", "shipping")
    }
    db.add_all([Company(id=cid, name="Copos"), Branch(id=bid, name="Matriz", company_id=cid), *users.values(),
                Product(sku="C1", name="Copo Twister", sale_price=2.8, cost_price=1.1, company_id=cid)])
    await db.commit()
    return users


@pytest.mark.asyncio
async def test_custo_e_margem_so_para_gestao(db, company):
    gestao = await build_company_context(company["admin"].company_id, db, company["admin"])
    vendedor = await build_company_context(company["seller"].company_id, db, company["seller"])
    assert "Custo" in gestao and "Margem" in gestao
    assert "Custo" not in vendedor and "Margem" not in vendedor
    assert "Copo Twister" in vendedor


@pytest.mark.asyncio
async def test_todos_os_setores_recebem_resposta_sem_erro(db, company):
    # Sem chave de IA: resposta explicativa, nunca exceção
    for user in company.values():
        answer = await ask_assistant("como faço um pedido?", user, db)
        assert "GROQ_API_KEY" in answer
