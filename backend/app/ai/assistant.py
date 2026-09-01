import unicodedata
import anthropic
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from app.core.config import settings
from app.repositories.stock_repository import StockRepository
from app.repositories.movement_repository import MovementRepository
from app.repositories.product_repository import ProductRepository
from app.repositories.branch_repository import BranchRepository
from app.ai.analytics import AnalyticsEngine


async def build_company_context(company_id: str, db: AsyncSession) -> str:
    """Monta um resumo textual dos dados da empresa para o prompt da IA."""
    prod_repo   = ProductRepository(db)
    stock_repo  = StockRepository(db)
    branch_repo = BranchRepository(db)
    mov_repo    = MovementRepository(db)

    branches  = await branch_repo.get_by_company(company_id)
    products  = await prod_repo.get_by_company(company_id)
    low_stock = await stock_repo.get_low_stock(company_id)
    movements = await mov_repo.get_recent_by_company(company_id, limit=20)

    branch_lines = "\n".join(
        f"  - {b.name} ({b.city}/{b.state})" for b in branches
    ) or "  Nenhuma filial cadastrada."

    product_lines = "\n".join(
        f"  - [{p.sku}] {p.name} | Preço: R${p.sale_price} | Custo: R${p.cost_price} | Margem: {p.margin_percent}%"
        for p in products[:30]
    ) or "  Nenhum produto cadastrado."

    low_lines = "\n".join(
        f"  - Produto {ls.product_id} na filial {ls.branch_id}: {ls.quantity} unid (mín {ls.min_quantity})"
        for ls in low_stock
    ) or "  Nenhum estoque crítico."

    mov_lines = "\n".join(
        f"  - {m.type.upper()} | Produto {m.product_id} | Qty {m.quantity} | {m.created_at.strftime('%d/%m %H:%M')}"
        for m in movements
    ) or "  Sem movimentações recentes."

    return f"""
DADOS DA EMPRESA (company_id: {company_id})

FILIAIS ({len(branches)}):
{branch_lines}

PRODUTOS ({len(products)}):
{product_lines}

ESTOQUES CRÍTICOS ({len(low_stock)}):
{low_lines}

ÚLTIMAS MOVIMENTAÇÕES:
{mov_lines}
""".strip()


def _norm(text: str) -> str:
    text = text.lower()
    return "".join(c for c in unicodedata.normalize("NFD", text) if unicodedata.category(c) != "Mn")


async def _load_analytics_engine(company_id: str, db: AsyncSession) -> AnalyticsEngine:
    from app.models.stock import Stock
    from app.models.product import Product as ProductModel

    prod_repo   = ProductRepository(db)
    branch_repo = BranchRepository(db)
    mov_repo    = MovementRepository(db)

    products  = await prod_repo.get_by_company(company_id, limit=500)
    branches  = await branch_repo.get_by_company(company_id)
    movements = await mov_repo.get_recent_by_company(company_id, limit=1000)

    stocks_q = await db.execute(
        select(Stock).join(ProductModel, Stock.product_id == ProductModel.id)
        .where(ProductModel.company_id == company_id)
    )
    stocks = stocks_q.scalars().all()

    return AnalyticsEngine(
        company_id=company_id,
        products=[{
            "id": p.id, "sku": p.sku, "name": p.name,
            "sale_price": float(p.sale_price), "cost_price": float(p.cost_price),
            "min_stock": p.min_stock, "category": p.category,
        } for p in products],
        branches=[{"id": b.id, "name": b.name, "city": b.city, "state": b.state} for b in branches],
        stocks=[{
            "id": s.id, "product_id": s.product_id, "branch_id": s.branch_id,
            "quantity": s.quantity, "min_quantity": s.min_quantity,
        } for s in stocks],
        movements=[{
            "id": m.id, "type": m.type, "quantity": m.quantity,
            "product_id": m.product_id, "branch_id": m.branch_id,
            "created_at": m.created_at.isoformat(),
        } for m in movements],
    )


# Padrões de pergunta -> categoria de alerta que respondem ela.
# Perguntas comuns não precisam de LLM: os dados já são calculados pelo
# AnalyticsEngine, só falta formatar em texto. Cada padrão é uma função
# (não frase exata) pra tolerar preenchimento tipo "meu estoque tá baixo?".
_CANNED_TOPICS = [
    (lambda q: any(w in q for w in ["dinheiro", "prejuizo"]) or "perdendo" in q,
     ["finance", "product"]),
    (lambda q: "estoque" in q and any(w in q for w in ["baixo", "critic", "acaband", "acabou", "repor", "reposic"]),
     ["stock"]),
    (lambda q: any(w in q for w in ["parad", "encalhad"]) or "nao vende" in q or "sem venda" in q,
     ["product"]),
    (lambda q: "queda" in q or "caindo" in q or "vendendo menos" in q,
     ["sales"]),
]


async def _try_canned_answer(question: str, company_id: str, db: AsyncSession) -> str | None:
    q = _norm(question)
    categories: set[str] | None = None
    for matches, cats in _CANNED_TOPICS:
        if matches(q):
            categories = set(cats)
            break
    if categories is None:
        return None

    engine = await _load_analytics_engine(company_id, db)
    report = engine.run()
    matched = [a for a in report.alerts if a.category in categories]

    if not matched:
        return "Nada de anormal encontrado por aqui — sem alertas nessa categoria no momento. 👍"

    lines = [f"Encontrei {len(matched)} ponto(s) de atenção:", ""]
    for a in sorted(matched, key=lambda x: 0 if x.severity == "critical" else 1)[:10]:
        icon = "🔴" if a.severity == "critical" else "🟡"
        lines.append(f"{icon} {a.title} — {a.detail}")
    return "\n".join(lines)


async def ask_assistant(question: str, company_id: str, db: AsyncSession) -> str:
    """
    Primeiro tenta responder com dados já calculados (sem custo de IA).
    Só cai pro Claude se a pergunta não bater com nenhum padrão conhecido.
    """
    canned = await _try_canned_answer(question, company_id, db)
    if canned is not None:
        return canned

    if not settings.ANTHROPIC_API_KEY:
        return "Chave da API Anthropic não configurada. Defina ANTHROPIC_API_KEY no .env."

    context = await build_company_context(company_id, db)

    system_prompt = f"""Você é o assistente IA do StockIQ, um ERP SaaS brasileiro.
Você tem acesso aos dados reais da empresa abaixo e deve responder com análises precisas,
diretas e acionáveis em português brasileiro. Use os dados para embasar cada resposta.
Não invente dados que não estão no contexto.

{context}"""

    client = anthropic.AsyncAnthropic(api_key=settings.ANTHROPIC_API_KEY)
    message = await client.messages.create(
        model="claude-sonnet-4-20250514",
        max_tokens=1024,
        system=system_prompt,
        messages=[{"role": "user", "content": question}],
    )
    return message.content[0].text
