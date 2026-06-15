"""
analytics_controller.py — Endpoints de IA/Analytics para o backend FastAPI.

Integra-se ao projeto da Fase 1.
Cole este arquivo em: backend/app/controllers/analytics_controller.py
Registre em main.py:  app.include_router(analytics_router, prefix=API)
"""
from fastapi import APIRouter, Depends, BackgroundTasks
from fastapi.responses import StreamingResponse, JSONResponse
from pydantic import BaseModel
from sqlalchemy.ext.asyncio import AsyncSession
from typing import Optional
import io

from app.core.database import get_db
from app.core.security import get_current_user, require_manager
from app.repositories.product_repository import ProductRepository
from app.repositories.branch_repository import BranchRepository
from app.repositories.stock_repository import StockRepository
from app.repositories.movement_repository import MovementRepository
from app.repositories.company_repository import CompanyRepository

from app.ai.analytics import AnalyticsEngine
from app.ai.predictions import run_forecasts
from app.ai.assistant import ask_assistant
from app.reports.pdf_report import generate_pdf

router = APIRouter(prefix="/analytics", tags=["Analytics & IA"])


# ── Helpers de carregamento de dados ──────────────────────────────────────────

async def _load_data(company_id: str, db: AsyncSession) -> dict:
    """Carrega todos os dados necessários para análise em paralelo."""
    prod_repo   = ProductRepository(db)
    branch_repo = BranchRepository(db)
    stock_repo  = StockRepository(db)
    mov_repo    = MovementRepository(db)
    comp_repo   = CompanyRepository(db)

    products  = await prod_repo.get_by_company(company_id, limit=500)
    branches  = await branch_repo.get_by_company(company_id)
    company   = await comp_repo.get_by_id(company_id)

    # Stocks e movimentos (todos da empresa via join)
    from sqlalchemy import select
    from app.models.stock import Stock
    from app.models.product import Product as ProductModel
    from app.models.movement import Movement

    stocks_q = await db.execute(
        select(Stock)
        .join(ProductModel, Stock.product_id == ProductModel.id)
        .where(ProductModel.company_id == company_id)
    )
    stocks = stocks_q.scalars().all()

    movements = await mov_repo.get_recent_by_company(company_id, limit=1000)

    def _prod_dict(p) -> dict:
        return {
            "id": p.id, "sku": p.sku, "name": p.name,
            "sale_price": float(p.sale_price),
            "cost_price": float(p.cost_price),
            "min_stock": p.min_stock,
            "category": p.category,
        }

    def _branch_dict(b) -> dict:
        return {"id": b.id, "name": b.name, "city": b.city, "state": b.state}

    def _stock_dict(s) -> dict:
        return {
            "id": s.id,
            "product_id": s.product_id,
            "branch_id": s.branch_id,
            "quantity": s.quantity,
            "min_quantity": s.min_quantity,
        }

    def _mov_dict(m) -> dict:
        return {
            "id": m.id,
            "type": m.type,
            "quantity": m.quantity,
            "product_id": m.product_id,
            "branch_id": m.branch_id,
            "created_at": m.created_at.isoformat(),
        }

    return {
        "company_id":   company_id,
        "company_name": company.name if company else "Empresa",
        "products":     [_prod_dict(p) for p in products],
        "branches":     [_branch_dict(b) for b in branches],
        "stocks":       [_stock_dict(s) for s in stocks],
        "movements":    [_mov_dict(m) for m in movements],
    }


# ── Endpoints ─────────────────────────────────────────────────────────────────

@router.get("/report", summary="Relatório completo de analytics da empresa")
async def get_analytics_report(
    db: AsyncSession = Depends(get_db),
    current_user=Depends(get_current_user),
):
    """
    Retorna análise completa: alertas, saúde de filiais,
    insights de produtos e resumo executivo.
    """
    data   = await _load_data(current_user.company_id, db)
    engine = AnalyticsEngine(
        company_id=data["company_id"],
        products=data["products"],
        branches=data["branches"],
        stocks=data["stocks"],
        movements=data["movements"],
    )
    report = engine.run()

    return {
        "generated_at":    report.generated_at.isoformat(),
        "company_id":      report.company_id,
        "summary":         report.summary,
        "alerts": [
            {
                "severity":    a.severity,
                "category":    a.category,
                "title":       a.title,
                "detail":      a.detail,
                "entity_id":   a.entity_id,
                "entity_name": a.entity_name,
                "metric":      a.metric,
                "unit":        a.unit,
            }
            for a in report.alerts
        ],
        "branch_health": [
            {
                "branch_id":       b.branch_id,
                "branch_name":     b.branch_name,
                "score":           b.score,
                "revenue":         b.revenue,
                "movement_count":  b.movement_count,
                "low_stock_count": b.low_stock_count,
                "trend":           b.trend,
            }
            for b in report.branch_health
        ],
        "product_insights": [
            {
                "product_id":     p.product_id,
                "product_name":   p.product_name,
                "sku":            p.sku,
                "days_stopped":   p.days_stopped,
                "total_stock":    p.total_stock,
                "margin":         p.margin,
                "recommendation": p.recommendation,
            }
            for p in report.product_insights
        ],
    }


@router.get("/forecast", summary="Previsão de demanda por produto")
async def get_forecast(
    db: AsyncSession = Depends(get_db),
    current_user=Depends(get_current_user),
):
    """
    Regressão linear por produto: demanda média, tendência,
    data de recompra recomendada e quantidade sugerida.
    """
    data = await _load_data(current_user.company_id, db)
    return run_forecasts(data["products"], data["stocks"], data["movements"])


@router.get("/alerts", summary="Apenas os alertas ativos")
async def get_alerts(
    db: AsyncSession = Depends(get_db),
    current_user=Depends(get_current_user),
):
    data   = await _load_data(current_user.company_id, db)
    engine = AnalyticsEngine(
        data["company_id"], data["products"],
        data["branches"], data["stocks"], data["movements"],
    )
    report = engine.run()
    return {
        "total":    len(report.alerts),
        "critical": sum(1 for a in report.alerts if a.severity == "critical"),
        "warning":  sum(1 for a in report.alerts if a.severity == "warning"),
        "alerts":   [
            {"severity": a.severity, "category": a.category, "title": a.title, "detail": a.detail}
            for a in report.alerts
        ],
    }


# ── IA Chat com histórico ─────────────────────────────────────────────────────

class AskRequest(BaseModel):
    question: str
    history: Optional[list[dict]] = None  # [{"role":"user","content":"..."}]


class AskResponse(BaseModel):
    answer: str
    company_id: str


@router.post("/ask", response_model=AskResponse, summary="Assistente IA com contexto completo")
async def ask(
    payload: AskRequest,
    db: AsyncSession = Depends(get_db),
    current_user=Depends(get_current_user),
):
    """
    Chat com o assistente IA do StockIQ.
    Contexto inclui analytics em tempo real da empresa.
    Suporta histórico multi-turn.
    """
    data   = await _load_data(current_user.company_id, db)
    answer = await ask_assistant(
        question=payload.question,
        company_id=data["company_id"],
        company_name=data["company_name"],
        products=data["products"],
        branches=data["branches"],
        stocks=data["stocks"],
        movements=data["movements"],
        history=payload.history,
    )
    return AskResponse(answer=answer, company_id=current_user.company_id)


# ── Relatório PDF ─────────────────────────────────────────────────────────────

@router.get(
    "/report/pdf",
    response_class=StreamingResponse,
    summary="Download do relatório executivo em PDF",
)
async def download_pdf(
    db: AsyncSession = Depends(get_db),
    current_user=Depends(require_manager),
):
    """
    Gera e retorna o relatório executivo completo em PDF.
    Inclui: capa, resumo, alertas, saúde de filiais,
    estoque crítico, previsão de demanda e insights.
    """
    data   = await _load_data(current_user.company_id, db)
    engine = AnalyticsEngine(
        data["company_id"], data["products"],
        data["branches"], data["stocks"], data["movements"],
    )
    report   = engine.run()
    forecast = run_forecasts(data["products"], data["stocks"], data["movements"])

    pdf_bytes = generate_pdf(
        company_id=data["company_id"],
        company_name=data["company_name"],
        products=data["products"],
        branches=data["branches"],
        stocks=data["stocks"],
        movements=data["movements"],
        analytics_report=report,
        forecast=forecast,
    )

    filename = f"stockiq_relatorio_{data['company_name'].replace(' ','_')}.pdf"
    return StreamingResponse(
        io.BytesIO(pdf_bytes),
        media_type="application/pdf",
        headers={"Content-Disposition": f'attachment; filename="{filename}"'},
    )
