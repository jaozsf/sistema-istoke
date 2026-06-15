"""
assistant.py — Assistente IA StockIQ.

Integra analytics + previsões + dados do banco em um único
contexto rico para o Claude responder com precisão.
"""
from __future__ import annotations
import anthropic
from typing import Any
from app.ai.analytics import AnalyticsEngine
from app.ai.predictions import run_forecasts
from app.core.config import settings


SYSTEM_TEMPLATE = """Você é o assistente executivo de IA do StockIQ, um ERP SaaS brasileiro.
Você age como um CFO/COO virtual: direto, analítico e orientado a ação.

REGRAS:
- Responda sempre em português brasileiro
- Use os dados fornecidos — nunca invente números
- Seja objetivo: no máximo 3 parágrafos por resposta
- Sempre termine com 1 ação concreta recomendada
- Use valores em Reais (R$) formatados com ponto como separador de milhar

DADOS DA EMPRESA ({company_name}):

=== RESUMO EXECUTIVO ===
{executive_summary}

=== ALERTAS ATIVOS ===
{alerts}

=== SAÚDE DAS FILIAIS ===
{branch_health}

=== ESTOQUE CRÍTICO ===
{critical_stock}

=== PREVISÃO DE DEMANDA ===
{demand_forecast}

=== PRODUTOS QUE PRECISAM DE ATENÇÃO ===
{product_insights}
"""


def _fmt_alerts(alerts: list) -> str:
    if not alerts:
        return "Nenhum alerta ativo."
    lines = []
    for a in alerts[:10]:
        icon = {"critical": "🔴", "warning": "🟡", "info": "🔵"}.get(a.severity, "•")
        lines.append(f"{icon} [{a.category.upper()}] {a.title}: {a.detail}")
    return "\n".join(lines)


def _fmt_branches(branches: list) -> str:
    lines = []
    for b in branches:
        trend_icon = {"up": "↑", "down": "↓", "stable": "→"}.get(b.trend, "→")
        lines.append(
            f"  • {b.branch_name}: Score {b.score}/100 {trend_icon} | "
            f"Receita estimada R${b.revenue:,.0f} | "
            f"{b.movement_count} movimentos | {b.low_stock_count} itens críticos"
        )
    return "\n".join(lines) if lines else "Sem dados de filiais."


def _fmt_forecast(forecast: dict) -> str:
    items = forecast.get("items", []) or forecast.get("predictions", [])[:5]
    if not items:
        return "Dados insuficientes para previsão."
    lines = [f"Total analisados: {forecast.get('total_forecasted', forecast.get('total_analyzed', 0))}"]
    for f in items[:5]:
        urgency_icon = {"urgente": "🔴", "imediato": "🔴", "breve": "🟡", "semana": "🟡"}.get(f.get("urgency", f.get("reorder_urgency","")), "🟢")
        dias = f.get('days_until_empty', f.get('days_until_empty', '?'))
        lines.append(
            f"  {urgency_icon} {f['product_name']} ({f['sku']}): "
            f"acaba em ~{dias}d | média {f.get('avg_daily_out', f.get('avg_daily_demand','?'))} unid/dia"
        )
    return "\n".join(lines)


def _fmt_product_insights(insights: list) -> str:
    if not insights:
        return "Sem insights de produtos."
    rec_map = {"comprar": "🛒 COMPRAR", "liquidar": "📉 LIQUIDAR", "monitorar": "👀 MONITORAR", "ok": "✅ OK"}
    lines = []
    for p in insights[:8]:
        lines.append(
            f"  {rec_map.get(p.recommendation, p.recommendation)} | "
            f"{p.product_name} | {p.total_stock} unid | "
            f"Margem {p.margin:.1f}% | "
            f"{'Parado ' + str(p.days_stopped) + 'd' if p.days_stopped > 0 else 'Ativo'}"
        )
    return "\n".join(lines)


def build_rich_context(
    company_id: str,
    company_name: str,
    products: list[dict],
    branches: list[dict],
    stocks: list[dict],
    movements: list[dict],
    finances: list[dict] | None = None,
) -> str:
    """Monta o contexto completo com analytics + previsões para o prompt."""
    engine   = AnalyticsEngine(company_id, products, branches, stocks, movements, finances)
    report   = engine.run()
    forecast = run_forecasts(products, stocks, movements)

    # Estoque crítico (apenas os piores)
    critical = [s for s in stocks if s["quantity"] <= s["min_quantity"]]
    critical_lines = []
    for s in critical[:8]:
        p = next((x for x in products if x["id"] == s["product_id"]), {})
        b = next((x for x in branches if x["id"] == s["branch_id"]), {})
        critical_lines.append(
            f"  • {p.get('name','?')} @ {b.get('name','?')}: "
            f"{s['quantity']} unid (mín {s['min_quantity']})"
        )

    summary = report.summary
    exec_summary = (
        f"Produtos: {summary['total_products']} | "
        f"Filiais: {summary['total_branches']} | "
        f"Alertas críticos: {summary['critical_alerts']} | "
        f"Alertas de aviso: {summary['warning_alerts']} | "
        f"Receita estimada: R${summary['estimated_revenue']:,.0f} | "
        f"Score médio filiais: {summary['avg_branch_score']}/100 | "
        f"Melhor filial: {summary['best_branch']} | "
        f"Pior filial: {summary['worst_branch']}"
    )

    return SYSTEM_TEMPLATE.format(
        company_name=company_name,
        executive_summary=exec_summary,
        alerts=_fmt_alerts(report.alerts),
        branch_health=_fmt_branches(report.branch_health),
        critical_stock="\n".join(critical_lines) if critical_lines else "Todos os estoques OK.",
        demand_forecast=_fmt_forecast(forecast),
        product_insights=_fmt_product_insights(report.product_insights),
    )


async def ask_assistant(
    question: str,
    company_id: str,
    company_name: str,
    products: list[dict],
    branches: list[dict],
    stocks: list[dict],
    movements: list[dict],
    finances: list[dict] | None = None,
    history: list[dict] | None = None,
) -> str:
    """
    Envia pergunta + contexto rico para o Claude.
    Suporta histórico de conversa multi-turn.
    """
    if not settings.ANTHROPIC_API_KEY:
        return "Chave ANTHROPIC_API_KEY não configurada no .env."

    system_prompt = build_rich_context(
        company_id, company_name,
        products, branches, stocks, movements, finances,
    )

    # Monta histórico
    messages: list[dict] = []
    for h in (history or []):
        messages.append({"role": h["role"], "content": h["content"]})
    messages.append({"role": "user", "content": question})

    client = anthropic.AsyncAnthropic(api_key=settings.ANTHROPIC_API_KEY)
    response = await client.messages.create(
        model="claude-sonnet-4-20250514",
        max_tokens=1024,
        system=system_prompt,
        messages=messages,
    )
    return response.content[0].text
