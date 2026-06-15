"""
predictions.py — Previsão de demanda usando regressão linear com
detecção de tendência e sazonalidade semanal.

Não usa sklearn para manter zero dependências externas além de numpy.
Implementa OLS (Ordinary Least Squares) nativamente.
"""
from __future__ import annotations
import math
from collections import defaultdict
from datetime import datetime, timedelta, timezone
from dataclasses import dataclass
from typing import Any


@dataclass
class DemandPrediction:
    product_id: str
    product_name: str
    sku: str
    # Histórico
    avg_daily_demand: float
    trend_daily: float          # variação diária da demanda (+ crescendo, - caindo)
    # Previsão
    predicted_30d: float
    predicted_60d: float
    predicted_90d: float
    # Compra recomendada
    reorder_qty: int
    reorder_urgency: str        # "imediato" | "semana" | "mes" | "ok"
    days_until_empty: int
    reorder_date: str
    # Confiança
    confidence: float           # 0.0 - 1.0
    data_points: int


@dataclass
class SeasonalPattern:
    """Padrão de demanda por dia da semana."""
    product_id: str
    weekday_indices: list[float]  # [seg, ter, qua, qui, sex, sab, dom] relativo à média


class DemandForecaster:
    """
    Gera previsões de demanda por produto.
    Recebe lista de movimentos já filtrados para a empresa.
    """

    def __init__(
        self,
        products: list[dict],
        stocks: list[dict],
        movements: list[dict],
        lead_time_days: int = 7,       # prazo de entrega do fornecedor
        safety_factor: float = 1.3,    # fator de segurança no pedido
    ):
        self.products      = {p["id"]: p for p in products}
        self.stocks        = stocks
        self.movements     = movements
        self.lead_time     = lead_time_days
        self.safety_factor = safety_factor
        self.now           = datetime.now(timezone.utc)

    def forecast_all(self) -> list[DemandPrediction]:
        predictions = []
        for pid in self.products:
            pred = self._forecast_product(pid)
            if pred:
                predictions.append(pred)
        return sorted(predictions, key=lambda p: p.days_until_empty)

    def seasonal_patterns(self) -> list[SeasonalPattern]:
        patterns = []
        for pid in self.products:
            pat = self._weekday_pattern(pid)
            if pat:
                patterns.append(pat)
        return patterns

    # ── Por produto ───────────────────────────────────────────────────────────

    def _forecast_product(self, product_id: str) -> DemandPrediction | None:
        product = self.products[product_id]

        # Coleta saídas dos últimos 60 dias em série diária
        daily = self._daily_demand(product_id, days=60)
        if len(daily) < 5:
            return None

        # Regressão linear simples (OLS)
        n     = len(daily)
        xs    = list(range(n))
        ys    = daily
        x_bar = sum(xs) / n
        y_bar = sum(ys) / n

        num   = sum((x - x_bar) * (y - y_bar) for x, y in zip(xs, ys))
        den   = sum((x - x_bar) ** 2 for x in xs)
        slope = num / den if den != 0 else 0.0
        intercept = y_bar - slope * x_bar

        # Previsões
        def predict(day_offset: int) -> float:
            return max(0.0, intercept + slope * (n + day_offset))

        avg_demand   = sum(daily[-14:]) / 14 if len(daily) >= 14 else y_bar
        pred_30      = sum(predict(d) for d in range(30))
        pred_60      = sum(predict(d) for d in range(60))
        pred_90      = sum(predict(d) for d in range(90))

        # Estoque atual
        total_stock = sum(
            s["quantity"] for s in self.stocks if s["product_id"] == product_id
        )

        days_empty  = int(total_stock / avg_demand) if avg_demand > 0 else 9999
        reorder_day = max(0, days_empty - self.lead_time)
        reorder_qty = int(avg_demand * (self.lead_time + 14) * self.safety_factor)

        # Urgência
        urgency = (
            "imediato" if days_empty <= self.lead_time else
            "semana"   if days_empty <= self.lead_time + 7 else
            "mes"      if days_empty <= 30 else
            "ok"
        )

        # Confiança: R² simplificado
        ss_res = sum((y - (intercept + slope * x)) ** 2 for x, y in zip(xs, ys))
        ss_tot = sum((y - y_bar) ** 2 for y in ys)
        r2     = 1 - ss_res / ss_tot if ss_tot > 0 else 0.0
        confidence = max(0.0, min(1.0, r2))

        return DemandPrediction(
            product_id=product_id,
            product_name=product["name"],
            sku=product["sku"],
            avg_daily_demand=round(avg_demand, 2),
            trend_daily=round(slope, 4),
            predicted_30d=round(pred_30),
            predicted_60d=round(pred_60),
            predicted_90d=round(pred_90),
            reorder_qty=max(0, reorder_qty),
            reorder_urgency=urgency,
            days_until_empty=min(days_empty, 9999),
            reorder_date=(self.now + timedelta(days=reorder_day)).strftime("%Y-%m-%d"),
            confidence=round(confidence, 2),
            data_points=n,
        )

    def _daily_demand(self, product_id: str, days: int) -> list[float]:
        cutoff = self.now - timedelta(days=days)
        daily: dict[str, float] = defaultdict(float)

        for m in self.movements:
            if m["product_id"] != product_id or m["type"] not in ("saida", "transfer"):
                continue
            try:
                ts = datetime.fromisoformat(m["created_at"].replace("Z", "+00:00"))
                if ts < cutoff:
                    continue
                day = ts.strftime("%Y-%m-%d")
                daily[day] += m["quantity"]
            except Exception:
                pass

        # Preenche dias sem movimento com 0
        result = []
        for d in range(days):
            dt  = (self.now - timedelta(days=days - d)).strftime("%Y-%m-%d")
            result.append(daily.get(dt, 0.0))
        return result

    def _weekday_pattern(self, product_id: str) -> SeasonalPattern | None:
        by_weekday: dict[int, list[float]] = defaultdict(list)
        for m in self.movements:
            if m["product_id"] != product_id or m["type"] != "saida":
                continue
            try:
                ts = datetime.fromisoformat(m["created_at"].replace("Z", "+00:00"))
                by_weekday[ts.weekday()].append(m["quantity"])
            except Exception:
                pass

        if len(by_weekday) < 4:
            return None

        avgs  = [sum(by_weekday.get(d, [0])) / max(len(by_weekday.get(d, [1])), 1) for d in range(7)]
        total = sum(avgs) / 7 if sum(avgs) > 0 else 1
        indices = [round(a / total, 2) for a in avgs]
        return SeasonalPattern(product_id=product_id, weekday_indices=indices)


# ── Função de conveniência para o controller ──────────────────────────────────

def run_forecasts(
    products: list[dict],
    stocks: list[dict],
    movements: list[dict],
) -> dict[str, Any]:
    forecaster   = DemandForecaster(products, stocks, movements)
    predictions  = forecaster.forecast_all()
    seasonal     = forecaster.seasonal_patterns()

    urgent = [p for p in predictions if p.reorder_urgency == "imediato"]
    soon   = [p for p in predictions if p.reorder_urgency == "semana"]

    return {
        "total_forecasted": len(predictions),
        "urgent_reorders":  len(urgent),
        "soon_reorders":    len(soon),
        "predictions": [
            {
                "product_id":       p.product_id,
                "product_name":     p.product_name,
                "sku":              p.sku,
                "avg_daily_demand": p.avg_daily_demand,
                "trend_daily":      p.trend_daily,
                "trend_direction":  "crescendo" if p.trend_daily > 0.05 else "caindo" if p.trend_daily < -0.05 else "estavel",
                "predicted_30d":    p.predicted_30d,
                "predicted_60d":    p.predicted_60d,
                "predicted_90d":    p.predicted_90d,
                "reorder_qty":      p.reorder_qty,
                "reorder_urgency":  p.reorder_urgency,
                "days_until_empty": p.days_until_empty,
                "reorder_date":     p.reorder_date,
                "confidence":       p.confidence,
                "data_points":      p.data_points,
            }
            for p in predictions
        ],
        "seasonal_patterns": [
            {
                "product_id":      s.product_id,
                "weekday_indices": s.weekday_indices,
                "peak_day":        ["Seg","Ter","Qua","Qui","Sex","Sáb","Dom"][
                                       s.weekday_indices.index(max(s.weekday_indices))
                                   ],
            }
            for s in seasonal
        ],
    }
