"""
Camada única de chamada ao modelo de linguagem do assistente (dúvidas).

Provedores com plano gratuito, sem cartão (ambos no formato OpenAI de
chat completions):
- Groq   -- https://api.groq.com/openai/v1, chave em console.groq.com/keys
- Gemini -- endpoint compatível do Google AI Studio, chave em aistudio.google.com/apikey
Anthropic (Claude) fica como alternativa paga.

Erro do provedor (limite do plano grátis, chave errada, fora do ar) vira
LLMError com mensagem pronta pro usuário -- o assistente nunca devolve 500
por causa da IA.
"""
import logging
import anthropic
import httpx
from app.core.config import settings

logger = logging.getLogger(__name__)

# provedor -> (base_url, modelo padrão)
_OPENAI_COMPAT = {
    "groq":   ("https://api.groq.com/openai/v1", "openai/gpt-oss-120b"),
    "gemini": ("https://generativelanguage.googleapis.com/v1beta/openai", "gemini-flash-latest"),
}


class LLMError(Exception):
    """Falha esperada do provedor, com texto já pronto pra mostrar."""


def _key_for(provider: str) -> str:
    return {
        "groq": settings.GROQ_API_KEY,
        "gemini": settings.GEMINI_API_KEY,
        "anthropic": settings.ANTHROPIC_API_KEY,
    }.get(provider, "")


def active_provider() -> str | None:
    wanted = settings.AI_PROVIDER.lower()
    if wanted != "auto":
        return wanted if _key_for(wanted) else None
    for p in ("groq", "gemini", "anthropic"):
        if _key_for(p):
            return p
    return None


async def complete(system: str, question: str, max_tokens: int = 1024) -> str:
    provider = active_provider()
    if provider in _OPENAI_COMPAT:
        return await _openai_compat(provider, system, question, max_tokens)
    if provider == "anthropic":
        return await _anthropic(system, question, max_tokens)
    raise LLMError(
        "A IA ainda não está configurada. O admin precisa cadastrar a chave grátis "
        "GROQ_API_KEY (ou GEMINI_API_KEY) nas variáveis do servidor."
    )


async def _openai_compat(provider: str, system: str, question: str, max_tokens: int) -> str:
    base_url, default_model = _OPENAI_COMPAT[provider]
    model = settings.AI_MODEL or default_model
    body = {
        "model": model,
        "messages": [
            {"role": "system", "content": system},
            {"role": "user", "content": question},
        ],
        "max_tokens": max_tokens,
        "temperature": 0.3,
    }
    # gpt-oss raciocina antes de responder; "low" = resposta mais rápida e
    # gasta menos da cota diária grátis.
    if "gpt-oss" in model:
        body["reasoning_effort"] = "low"

    try:
        async with httpx.AsyncClient(timeout=httpx.Timeout(45, connect=10)) as client:
            resp = await client.post(
                f"{base_url}/chat/completions",
                json=body,
                headers={"Authorization": f"Bearer {_key_for(provider)}"},
            )
    except httpx.TimeoutException:
        raise LLMError("A IA demorou demais pra responder. Tente de novo em instantes.")
    except httpx.HTTPError as exc:
        logger.warning("Falha de rede com %s: %s", provider, exc)
        raise LLMError("Não consegui falar com a IA agora. Tente de novo em instantes.")

    if resp.status_code == 429:
        raise LLMError(
            "Limite gratuito da IA atingido por agora. Espere alguns minutos e pergunte de novo."
        )
    if resp.status_code in (401, 403):
        logger.warning("%s recusou a chave (%s): %s", provider, resp.status_code, resp.text[:300])
        raise LLMError("A IA recusou o acesso: a chave está inválida. O admin precisa conferir a chave.")
    if resp.status_code >= 400:
        logger.warning("%s respondeu %s: %s", provider, resp.status_code, resp.text[:300])
        raise LLMError("A IA está com problema no momento. Tente de novo mais tarde.")

    try:
        text = (resp.json()["choices"][0]["message"].get("content") or "").strip()
    except (ValueError, KeyError, IndexError):
        text = ""
    if not text:
        raise LLMError("A IA não devolveu resposta. Tente reformular a pergunta.")
    return text


async def _anthropic(system: str, question: str, max_tokens: int) -> str:
    client = anthropic.AsyncAnthropic(api_key=settings.ANTHROPIC_API_KEY)
    try:
        message = await client.messages.create(
            model=settings.AI_MODEL or settings.ANTHROPIC_MODEL,
            max_tokens=max_tokens,
            system=system,
            messages=[{"role": "user", "content": question}],
        )
    except anthropic.RateLimitError:
        raise LLMError("Limite de uso da IA atingido por agora. Espere alguns minutos e pergunte de novo.")
    except anthropic.APIError as exc:
        logger.warning("Falha na Anthropic: %s", exc)
        raise LLMError("A IA está com problema no momento. Tente de novo mais tarde.")
    return message.content[0].text
