"""
pdf_report.py — Gerador de relatório executivo em PDF.

Gera um PDF profissional com:
  - Capa com logo e dados da empresa
  - Resumo executivo com métricas
  - Alertas ativos por severidade
  - Tabela de saúde de filiais
  - Tabela de estoque crítico
  - Previsão de demanda
  - Gráfico de barras de receita por filial (ASCII-style em tabela)
  - Rodapé com data e página
"""
from __future__ import annotations
import io
from datetime import datetime, timezone
from typing import Any

from reportlab.lib.pagesizes import A4
from reportlab.lib import colors
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import cm, mm
from reportlab.lib.enums import TA_CENTER, TA_LEFT, TA_RIGHT
from reportlab.platypus import (
    SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle,
    HRFlowable, KeepTogether, PageBreak,
)
from reportlab.graphics.shapes import Drawing, Rect, String
from reportlab.graphics import renderPDF
from reportlab.graphics.charts.barcharts import VerticalBarChart

# ── Paleta de cores ───────────────────────────────────────────────────────────

C_PRIMARY  = colors.HexColor("#534AB7")
C_SUCCESS  = colors.HexColor("#1D9E75")
C_WARNING  = colors.HexColor("#BA7517")
C_DANGER   = colors.HexColor("#E24B4A")
C_INFO     = colors.HexColor("#185FA5")
C_GRAY     = colors.HexColor("#888780")
C_LIGHT    = colors.HexColor("#F5F5F0")
C_BORDER   = colors.HexColor("#E8E6DE")
C_TEXT     = colors.HexColor("#1A1A19")
C_MUTED    = colors.HexColor("#666664")
C_WHITE    = colors.white


def _styles() -> dict:
    base = getSampleStyleSheet()
    return {
        "title":    ParagraphStyle("title",    fontName="Helvetica-Bold",   fontSize=22, textColor=C_PRIMARY,  spaceAfter=4,  alignment=TA_CENTER),
        "subtitle": ParagraphStyle("subtitle", fontName="Helvetica",        fontSize=12, textColor=C_MUTED,    spaceAfter=2,  alignment=TA_CENTER),
        "h1":       ParagraphStyle("h1",       fontName="Helvetica-Bold",   fontSize=14, textColor=C_PRIMARY,  spaceAfter=6,  spaceBefore=14),
        "h2":       ParagraphStyle("h2",       fontName="Helvetica-Bold",   fontSize=11, textColor=C_TEXT,     spaceAfter=4,  spaceBefore=8),
        "body":     ParagraphStyle("body",     fontName="Helvetica",        fontSize=9,  textColor=C_TEXT,     spaceAfter=3,  leading=13),
        "small":    ParagraphStyle("small",    fontName="Helvetica",        fontSize=8,  textColor=C_MUTED,    spaceAfter=2),
        "bold":     ParagraphStyle("bold",     fontName="Helvetica-Bold",   fontSize=9,  textColor=C_TEXT),
        "center":   ParagraphStyle("center",   fontName="Helvetica",        fontSize=9,  textColor=C_TEXT,     alignment=TA_CENTER),
        "right":    ParagraphStyle("right",    fontName="Helvetica",        fontSize=9,  textColor=C_TEXT,     alignment=TA_RIGHT),
        "alert_c":  ParagraphStyle("alert_c",  fontName="Helvetica-Bold",   fontSize=9,  textColor=C_DANGER),
        "alert_w":  ParagraphStyle("alert_w",  fontName="Helvetica-Bold",   fontSize=9,  textColor=C_WARNING),
        "alert_i":  ParagraphStyle("alert_i",  fontName="Helvetica",        fontSize=9,  textColor=C_INFO),
        "green":    ParagraphStyle("green",    fontName="Helvetica-Bold",   fontSize=9,  textColor=C_SUCCESS),
        "footer":   ParagraphStyle("footer",   fontName="Helvetica",        fontSize=7,  textColor=C_MUTED,    alignment=TA_CENTER),
    }


# ── Table style helpers ───────────────────────────────────────────────────────

def _header_style(bg=C_PRIMARY) -> list:
    return [
        ("BACKGROUND",   (0, 0), (-1, 0), bg),
        ("TEXTCOLOR",    (0, 0), (-1, 0), C_WHITE),
        ("FONTNAME",     (0, 0), (-1, 0), "Helvetica-Bold"),
        ("FONTSIZE",     (0, 0), (-1, 0), 8),
        ("ALIGN",        (0, 0), (-1, 0), "CENTER"),
        ("BOTTOMPADDING",(0, 0), (-1, 0), 6),
        ("TOPPADDING",   (0, 0), (-1, 0), 6),
    ]


def _row_style() -> list:
    return [
        ("FONTNAME",     (0, 1), (-1, -1), "Helvetica"),
        ("FONTSIZE",     (0, 1), (-1, -1), 8),
        ("ROWBACKGROUNDS",(0, 1), (-1, -1), [C_WHITE, C_LIGHT]),
        ("GRID",         (0, 0), (-1, -1), 0.25, C_BORDER),
        ("VALIGN",       (0, 0), (-1, -1), "MIDDLE"),
        ("TOPPADDING",   (0, 1), (-1, -1), 4),
        ("BOTTOMPADDING",(0, 1), (-1, -1), 4),
        ("LEFTPADDING",  (0, 0), (-1, -1), 6),
        ("RIGHTPADDING", (0, 0), (-1, -1), 6),
    ]


# ── Seções do relatório ───────────────────────────────────────────────────────

def _build_cover(s, company_name: str, generated_at: datetime) -> list:
    items = [
        Spacer(1, 3 * cm),
        Paragraph("StockIQ", s["title"]),
        Paragraph("Relatório Executivo de Inteligência Operacional", s["subtitle"]),
        Spacer(1, 0.5 * cm),
        HRFlowable(width="100%", thickness=1, color=C_PRIMARY),
        Spacer(1, 0.5 * cm),
        Paragraph(company_name, ParagraphStyle("co", fontName="Helvetica-Bold", fontSize=16, textColor=C_TEXT, alignment=TA_CENTER)),
        Spacer(1, 0.3 * cm),
        Paragraph(
            f"Gerado em {generated_at.strftime('%d/%m/%Y às %H:%M')} UTC",
            s["subtitle"],
        ),
        Spacer(1, 5 * cm),
        Paragraph(
            "Este relatório foi gerado automaticamente pelo módulo de IA do StockIQ.<br/>"
            "Contém análise de estoque, saúde de filiais, alertas e previsão de demanda.",
            ParagraphStyle("disc", fontName="Helvetica", fontSize=9, textColor=C_MUTED, alignment=TA_CENTER, leading=14),
        ),
        PageBreak(),
    ]
    return items


def _build_summary(s, summary: dict) -> list:
    items = [Paragraph("1. Resumo Executivo", s["h1"])]

    # Métricas em grid 2×3
    metrics = [
        ("Produtos",         str(summary.get("total_products", 0)),   C_TEXT),
        ("Filiais",          str(summary.get("total_branches", 0)),   C_TEXT),
        ("Movimentações",    str(summary.get("total_movements", 0)),  C_TEXT),
        ("Alertas críticos", str(summary.get("critical_alerts", 0)),  C_DANGER),
        ("Alertas de aviso", str(summary.get("warning_alerts", 0)),   C_WARNING),
        ("Score médio",      f"{summary.get('avg_branch_score', 0):.0f}/100", C_SUCCESS),
    ]

    data = [["Métrica", "Valor"] * 3]
    row  = []
    for i, (label, value, color) in enumerate(metrics):
        row.append(Paragraph(label, s["small"]))
        row.append(Paragraph(f"<b>{value}</b>", ParagraphStyle("mv", fontName="Helvetica-Bold", fontSize=11, textColor=color, alignment=TA_CENTER)))
        if len(row) == 6:
            data.append(row)
            row = []

    t = Table(data, colWidths=[3.5*cm, 2*cm, 3.5*cm, 2*cm, 3.5*cm, 2*cm])
    t.setStyle(TableStyle([
        ("GRID",     (0,0), (-1,-1), 0.25, C_BORDER),
        ("BACKGROUND",(0,0),(-1,-1), C_LIGHT),
        ("VALIGN",   (0,0), (-1,-1), "MIDDLE"),
        ("ALIGN",    (1,0), (1,-1), "CENTER"),
        ("ALIGN",    (3,0), (3,-1), "CENTER"),
        ("ALIGN",    (5,0), (5,-1), "CENTER"),
        ("TOPPADDING",(0,0),(-1,-1), 8),
        ("BOTTOMPADDING",(0,0),(-1,-1), 8),
        ("LEFTPADDING",(0,0),(-1,-1), 8),
    ]))
    items.append(t)

    # Melhores e piores filiais
    if summary.get("best_branch") or summary.get("worst_branch"):
        items.append(Spacer(1, 0.3*cm))
        items.append(Paragraph(
            f"<b>Melhor filial:</b> {summary.get('best_branch', '-')}  |  "
            f"<b>Filial com pior performance:</b> {summary.get('worst_branch', '-')}",
            s["body"],
        ))
    items.append(Spacer(1, 0.4*cm))
    return items


def _build_alerts(s, alerts: list) -> list:
    items = [Paragraph("2. Alertas Ativos", s["h1"])]
    if not alerts:
        items.append(Paragraph("Nenhum alerta ativo. Todos os indicadores dentro do esperado.", s["body"]))
        return items

    icon_map   = {"critical": "CRITICO", "warning": "AVISO", "info": "INFO"}
    color_map  = {"critical": C_DANGER,  "warning": C_WARNING, "info": C_INFO}
    bg_map     = {"critical": colors.HexColor("#FCEBEB"), "warning": colors.HexColor("#FAEEDA"), "info": colors.HexColor("#E6F1FB")}

    data = [["Sev.", "Categoria", "Título", "Detalhe"]]
    styles_rows: list[tuple] = []

    for i, a in enumerate(alerts[:20], 1):
        sev_style = ParagraphStyle(
            f"sev{i}", fontName="Helvetica-Bold", fontSize=7,
            textColor=color_map.get(a.severity, C_GRAY),
        )
        data.append([
            Paragraph(icon_map.get(a.severity, ""), sev_style),
            Paragraph(a.category.upper(), s["small"]),
            Paragraph(a.title, s["bold"]),
            Paragraph(a.detail, s["small"]),
        ])
        bg = bg_map.get(a.severity, C_LIGHT)
        styles_rows.append(("BACKGROUND", (0, i), (-1, i), bg))

    t = Table(data, colWidths=[1.3*cm, 2.2*cm, 4.5*cm, 8.5*cm])
    style = _header_style() + _row_style() + styles_rows
    t.setStyle(TableStyle(style))
    items.append(t)
    items.append(Spacer(1, 0.4*cm))
    return items


def _build_branch_health(s, branches: list) -> list:
    items = [Paragraph("3. Saúde das Filiais", s["h1"])]
    if not branches:
        items.append(Paragraph("Sem dados de filiais.", s["body"]))
        return items

    data = [["Filial", "Score", "Tendência", "Receita Est.", "Movimentos", "Itens Críticos"]]
    for b in branches:
        trend_txt = {"up": "Crescendo ↑", "down": "Caindo ↓", "stable": "Estável →"}.get(b.trend, "—")
        score_color = C_SUCCESS if b.score >= 70 else C_WARNING if b.score >= 40 else C_DANGER
        score_style = ParagraphStyle("sc", fontName="Helvetica-Bold", fontSize=9, textColor=score_color, alignment=TA_CENTER)
        data.append([
            Paragraph(b.branch_name, s["body"]),
            Paragraph(str(b.score), score_style),
            Paragraph(trend_txt, s["center"]),
            Paragraph(f"R${b.revenue:,.0f}", s["right"]),
            Paragraph(str(b.movement_count), s["center"]),
            Paragraph(str(b.low_stock_count), s["center"]),
        ])

    t = Table(data, colWidths=[5*cm, 1.8*cm, 3*cm, 3.2*cm, 2.5*cm, 2.5*cm])
    t.setStyle(TableStyle(_header_style() + _row_style()))
    items.append(t)
    items.append(Spacer(1, 0.4*cm))
    return items


def _build_critical_stock(s, stocks: list, products: dict, branches: dict) -> list:
    items = [Paragraph("4. Estoque Crítico", s["h1"])]
    critical = [x for x in stocks if x["quantity"] <= x["min_quantity"]]

    if not critical:
        items.append(Paragraph("Todos os estoques acima do mínimo. Nenhuma ação necessária.", s["green"]))
        return items

    data = [["Produto", "SKU", "Filial", "Qtd Atual", "Mín.", "% do Mínimo"]]
    for sc in sorted(critical, key=lambda x: x["quantity"])[:20]:
        p   = products.get(sc["product_id"], {})
        b   = branches.get(sc["branch_id"], {})
        pct = sc["quantity"] / max(sc["min_quantity"], 1) * 100
        pct_color = C_DANGER if pct == 0 else C_WARNING if pct < 50 else C_TEXT
        pct_style = ParagraphStyle("pct", fontName="Helvetica-Bold", fontSize=9, textColor=pct_color, alignment=TA_RIGHT)
        data.append([
            Paragraph(p.get("name", sc["product_id"]), s["body"]),
            Paragraph(p.get("sku", "—"), s["small"]),
            Paragraph(b.get("name", sc["branch_id"]), s["body"]),
            Paragraph(str(sc["quantity"]), s["center"]),
            Paragraph(str(sc["min_quantity"]), s["center"]),
            Paragraph(f"{pct:.0f}%", pct_style),
        ])

    t = Table(data, colWidths=[5.5*cm, 1.8*cm, 3.5*cm, 2*cm, 1.8*cm, 2.4*cm])
    t.setStyle(TableStyle(_header_style(C_DANGER) + _row_style()))
    items.append(t)
    items.append(Spacer(1, 0.4*cm))
    return items


def _build_forecast(s, forecast: dict) -> list:
    items = [Paragraph("5. Previsão de Demanda", s["h1"])]
    predictions = forecast.get("predictions", forecast.get("items", []))

    if not predictions:
        items.append(Paragraph("Dados insuficientes para gerar previsões. Adicione movimentações para habilitar.", s["body"]))
        return items

    items.append(Paragraph(
        f"<b>{forecast.get('urgent_reorders', 0)}</b> produtos precisam de recompra imediata | "
        f"<b>{forecast.get('soon_reorders', 0)}</b> em breve | "
        f"Total analisados: <b>{forecast.get('total_forecasted', 0)}</b>",
        s["body"],
    ))
    items.append(Spacer(1, 0.2*cm))

    urg_map = {
        "imediato": ("IMEDIATO", C_DANGER),
        "semana":   ("SEMANA",   C_WARNING),
        "mes":      ("MES",      C_INFO),
        "ok":       ("OK",       C_SUCCESS),
        "urgente":  ("URGENTE",  C_DANGER),
        "breve":    ("BREVE",    C_WARNING),
    }
    data = [["Produto", "SKU", "Demanda/dia", "Tendência", "Estoque acaba em", "Urgência", "Qtd. Recompra"]]
    for p in predictions[:15]:
        urg_key = p.get("reorder_urgency", p.get("urgency", "ok"))
        urg_txt, urg_color = urg_map.get(urg_key, ("OK", C_SUCCESS))
        urg_style = ParagraphStyle("u", fontName="Helvetica-Bold", fontSize=8, textColor=urg_color, alignment=TA_CENTER)
        trend = p.get("trend_direction", "estavel")
        trend_txt = {"crescendo": "↑ Crescendo", "caindo": "↓ Caindo", "estavel": "→ Estável"}.get(trend, "—")
        dias = p.get("days_until_empty", "?")
        data.append([
            Paragraph(p["product_name"], s["body"]),
            Paragraph(p["sku"], s["small"]),
            Paragraph(str(p.get("avg_daily_demand", p.get("avg_daily_out","?"))), s["center"]),
            Paragraph(trend_txt, s["small"]),
            Paragraph(f"~{dias}d ({p.get('reorder_date','?')})", s["center"]),
            Paragraph(urg_txt, urg_style),
            Paragraph(str(p.get("reorder_qty", "—")), s["center"]),
        ])

    t = Table(data, colWidths=[4.5*cm, 1.5*cm, 2*cm, 2.5*cm, 3*cm, 2*cm, 2*cm])
    t.setStyle(TableStyle(_header_style(C_INFO) + _row_style()))
    items.append(t)
    items.append(Spacer(1, 0.4*cm))
    return items


def _build_product_insights(s, insights: list) -> list:
    items = [Paragraph("6. Insights de Produtos", s["h1"])]
    if not insights:
        items.append(Paragraph("Sem insights disponíveis.", s["body"]))
        return items

    rec_map = {
        "comprar":   ("COMPRAR",   C_SUCCESS),
        "liquidar":  ("LIQUIDAR",  C_DANGER),
        "monitorar": ("MONITORAR", C_WARNING),
        "ok":        ("OK",        C_MUTED),
    }
    data = [["Produto", "SKU", "Estoque Total", "Margem", "Dias Parado", "Recomendação"]]
    for p in insights[:15]:
        rec_txt, rec_color = rec_map.get(p.recommendation, ("—", C_MUTED))
        rec_style = ParagraphStyle("r", fontName="Helvetica-Bold", fontSize=8, textColor=rec_color, alignment=TA_CENTER)
        data.append([
            Paragraph(p.product_name, s["body"]),
            Paragraph(p.sku, s["small"]),
            Paragraph(str(p.total_stock), s["center"]),
            Paragraph(f"{p.margin:.1f}%", s["center"]),
            Paragraph(str(p.days_stopped) if p.days_stopped >= 0 else "—", s["center"]),
            Paragraph(rec_txt, rec_style),
        ])

    t = Table(data, colWidths=[5.5*cm, 1.8*cm, 2.5*cm, 2*cm, 2.5*cm, 3.2*cm])
    t.setStyle(TableStyle(_header_style(C_PRIMARY) + _row_style()))
    items.append(t)
    return items


# ── Paginação ─────────────────────────────────────────────────────────────────

def _footer(canvas, doc):
    canvas.saveState()
    canvas.setFont("Helvetica", 7)
    canvas.setFillColor(C_MUTED)
    w, _ = A4
    canvas.drawCentredString(w / 2, 1.2*cm, f"StockIQ — Relatório Executivo  •  Página {doc.page}")
    canvas.drawString(1.5*cm, 1.2*cm, datetime.now(timezone.utc).strftime("%d/%m/%Y %H:%M UTC"))
    canvas.drawRightString(w - 1.5*cm, 1.2*cm, "Confidencial")
    canvas.restoreState()


# ── Ponto de entrada ──────────────────────────────────────────────────────────

def generate_pdf(
    company_id: str,
    company_name: str,
    products: list[dict],
    branches: list[dict],
    stocks: list[dict],
    movements: list[dict],
    analytics_report: Any,
    forecast: dict,
) -> bytes:
    """
    Gera o relatório PDF completo e retorna os bytes para download.
    """
    buffer = io.BytesIO()
    doc = SimpleDocTemplate(
        buffer,
        pagesize=A4,
        leftMargin=1.5*cm,
        rightMargin=1.5*cm,
        topMargin=1.5*cm,
        bottomMargin=2*cm,
        title=f"StockIQ — Relatório {company_name}",
        author="StockIQ IA",
        subject="Relatório Executivo de Estoque e Performance",
    )

    s    = _styles()
    now  = datetime.now(timezone.utc)
    prod_dict   = {p["id"]: p for p in products}
    branch_dict = {b["id"]: b for b in branches}

    story = []
    story += _build_cover(s, company_name, now)
    story += _build_summary(s, analytics_report.summary)
    story += _build_alerts(s, analytics_report.alerts)
    story += _build_branch_health(s, analytics_report.branch_health)
    story += _build_critical_stock(s, stocks, prod_dict, branch_dict)
    story += _build_forecast(s, forecast)
    story += _build_product_insights(s, analytics_report.product_insights)

    doc.build(story, onFirstPage=_footer, onLaterPages=_footer)
    return buffer.getvalue()
