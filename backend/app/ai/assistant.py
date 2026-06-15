import anthropic
from sqlalchemy.ext.asyncio import AsyncSession
from app.core.config import settings
from app.repositories.stock_repository import StockRepository
from app.repositories.movement_repository import MovementRepository
from app.repositories.product_repository import ProductRepository
from app.repositories.branch_repository import BranchRepository


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


async def ask_assistant(question: str, company_id: str, db: AsyncSession) -> str:
    """
    Envia a pergunta + contexto real da empresa para o Claude.
    Retorna a resposta em texto.
    """
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
