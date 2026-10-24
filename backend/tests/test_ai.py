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
