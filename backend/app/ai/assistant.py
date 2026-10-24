import unicodedata
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from app.repositories.stock_repository import StockRepository
from app.repositories.movement_repository import MovementRepository
from app.repositories.product_repository import ProductRepository
from app.repositories.branch_repository import BranchRepository
from app.ai.analytics import AnalyticsEngine
from app.ai.llm import complete, LLMError


MANAGER_ROLES = ("admin", "manager")

ROLE_LABELS = {
    "admin": "admin (dono)", "manager": "gerente", "seller": "vendedor",
    "production": "produção", "shipping": "expedição", "operator": "operador",
}


async def build_company_context(company_id: str, db: AsyncSession, user=None) -> str:
    """
    Resumo dos dados da empresa para o prompt. Custo, margem e pedidos de
    outros vendedores só entram para admin/gerente -- o assistente é aberto a
    todos os setores e não pode vazar o que a tela da pessoa não mostra.
    """
    full_access = user is None or user.role in MANAGER_ROLES
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
        f"  - [{p.sku}] {p.name} | Preço: R${p.sale_price}"
        + (f" | Custo: R${p.cost_price} | Margem: {p.margin_percent}%" if full_access else "")
        for p in products[:30]
    ) or "  Nenhum produto cadastrado."

    pname = {p.id: p.name for p in products}
    bname = {b.id: b.name for b in branches}

    low_lines = "\n".join(
        f"  - {pname.get(ls.product_id, ls.product_id)} na filial {bname.get(ls.branch_id, ls.branch_id)}: "
        f"{ls.quantity} unid (mín {ls.min_quantity})"
        for ls in low_stock
    ) or "  Nenhum estoque crítico."

    mov_lines = "\n".join(
        f"  - {m.type.upper()} | {pname.get(m.product_id, m.product_id)} | Qtd {m.quantity} | "
        f"{m.created_at.strftime('%d/%m %H:%M')}"
        for m in movements
    ) or "  Sem movimentações recentes."

    seller_id = user.id if user is not None and user.role == "seller" else None
    order_lines = await _orders_context(company_id, db, seller_id)

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

{order_lines}
""".strip()


async def _orders_context(company_id: str, db: AsyncSession, seller_id: str | None = None) -> str:
    """Pedidos por etapa + últimos pedidos, padrões de caixa e distribuidoras."""
    from sqlalchemy import func
    from app.models.order import Order
    from app.models.partner import Customer, Distributor
    from app.models.box_standard import BoxStandard
    from app.models.product import Product

    # Vendedor só enxerga a própria carteira, igual na tela de pedidos
    scope = [Order.company_id == company_id]
    if seller_id:
        scope.append(Order.seller_id == seller_id)
    counts = dict((await db.execute(
        select(Order.status, func.count()).where(*scope).group_by(Order.status)
    )).all())
    recent = (await db.execute(
        select(Order, Customer.name)
        .join(Customer, Customer.id == Order.customer_id)
        .where(*scope)
        .order_by(Order.created_at.desc()).limit(15)
    )).all()
    boxes = (await db.execute(
        select(Product.name, BoxStandard.units_per_box)
        .join(BoxStandard, BoxStandard.product_id == Product.id)
        .where(Product.company_id == company_id)
    )).all()
    dists = (await db.execute(
        select(Distributor.name).where(Distributor.company_id == company_id, Distributor.is_active == True)  # noqa: E712
    )).scalars().all()

    count_line = ", ".join(f"{k}: {v}" for k, v in counts.items()) or "nenhum pedido ainda"
    recent_lines = "\n".join(
        f"  - #{o.number:04d} | {cname} | {o.status} | {o.total_boxes} cx / {o.total_units} un"
        for o, cname in recent
    ) or "  Nenhum pedido."
    box_lines = "\n".join(f"  - {n}: {u} un/caixa" for n, u in boxes) or "  Nenhum padrão cadastrado."
    return f"""PEDIDOS POR ETAPA: {count_line}

ÚLTIMOS PEDIDOS:
{recent_lines}

PADRÕES DE CAIXA:
{box_lines}

DISTRIBUIDORAS ATIVAS: {", ".join(dists) or "nenhuma"}"""


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


async def _try_canned_answer(
    question: str, company_id: str, db: AsyncSession, full_access: bool = True,
) -> str | None:
    q = _norm(question)
    categories: set[str] | None = None
    for matches, cats in _CANNED_TOPICS:
        if matches(q):
            categories = set(cats)
            break
    if categories is None:
        return None
    # Alertas de dinheiro/produto citam custo e margem: só para gestão
    if not full_access and categories & {"finance", "product"}:
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


async def ask_assistant(question: str, user, db: AsyncSession) -> str:
    """
    Primeiro tenta responder com dados já calculados (sem custo de IA).
    Só chama o modelo de IA se a pergunta não bater com nenhum padrão conhecido.
    """
    company_id = user.company_id
    full_access = user.role in MANAGER_ROLES
    canned = await _try_canned_answer(question, company_id, db, full_access)
    if canned is not None:
        return canned

    context = await build_company_context(company_id, db, user)
    role = ROLE_LABELS.get(user.role, user.role)
    restriction = "" if full_access else (
        "\nQuem pergunta não é da gestão: não fale de custo, margem, lucro nem dados financeiros; "
        "se pedirem, diga que só admin/gerente vê isso."
    )
    system_prompt = f"""{SYSTEM_GUIDE}

QUEM PERGUNTA: {user.full_name}, setor {role}. Explique o passo a passo do setor dele quando fizer sentido.{restriction}

Use os dados reais da empresa abaixo para embasar as respostas sobre o negócio.
Não invente números que não estão aqui; se faltar dado, diga o que falta.

{context}"""

    try:
        return await complete(system_prompt, question)
    except LLMError as exc:
        return str(exc)


# O que o assistente sabe sobre o próprio sistema -- para tirar dúvidas de
# uso ("como faço um pedido?") sem precisar de manual.
SYSTEM_GUIDE = """Você é o assistente do StockIQ, ERP brasileiro para fábricas e distribuidoras de copos.
Responda em português do Brasil, curto e direto, em passos numerados quando for "como faço".

COMO O SISTEMA FUNCIONA
- Perfis: admin (dono, faz tudo), gerente, vendedor, produção, expedição, operador.
- Produtos: modelos de copo com SKU, preço de venda, custo e estoque mínimo. QR Code por produto.
- Estoque: entrada, saída, transferência entre filiais e ajuste (só admin). Alerta quando cai abaixo do mínimo.
- Padrão de caixa (Gestão > Padrões de caixa, só admin): unidades por caixa, medidas e peso de cada modelo.
  Produto sem padrão não pode ser pedido.
- Distribuidoras (Gestão > Distribuidoras, só admin). O vendedor escolhe com o cliente em cada pedido.
- Pedido: vendedor cria em Pedidos > Novo pedido, escolhe cliente, distribuidora e copos EM CAIXAS,
  marca arte e/ou borda se for personalizado e toca em "Enviar à fábrica".
- Etapas: Enviado -> Em produção (só se tiver arte/borda; a produção inicia) -> Em separação
  (expedição separa) -> Conferido (expedição conta caixa a caixa; só libera quando bate) ->
  Despachado (entregue à distribuidora com NF). O estoque baixa quando o pedido sai de "Enviado".
- Cancelar: gerente/admin em qualquer etapa aberta; vendedor só em "Enviado". Cancelar devolve o estoque.
- Arte custa R$ 2,00 e borda R$ 1,00 a mais por unidade. Copo ecológico não aceita borda (derrete).
- Equipe: admin cadastra pessoas pelo e-mail em Gestão > Equipe e setores e escolhe o setor.
- Tema claro/escuro em Gestão ou Conta > Aparência. Etiquetas QR em PDF na tela de Produtos.

Se a pergunta não for sobre o StockIQ, o negócio da empresa ou gestão de estoque/vendas,
responda brevemente e volte ao assunto. Nunca peça nem revele senhas ou chaves."""
