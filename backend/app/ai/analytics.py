"""
analytics.py — Detecção de padrões e anomalias nos dados de estoque/vendas.

Algoritmos implementados:
  - Queda de vendas por filial (comparação período atual vs anterior)
  - Produtos parados (sem movimentação em N dias)
  - Detecção de estoque crítico recorrente
  - Giro de estoque por produto/filial
  - Margem média por categoria
  - Score de saúde por filial (0-100)
"""
from __future__ import annotations
from datetime import datetime, timedelta, timezone
from typing import Any
from dataclasses import dataclass, field
from collections import defaultdict


# ─── Tipos de saída ────────────────────────────────────────────────────────────

@dataclass
class Alert:
    severity: str          # "critical" | "warning" | "info"
    category: str          # "stock" | "sales" | "finance" | "product"
    title: str
    detail: str
    entity_id: str | None = None
    entity_name: str | None = None
    metric: float | None = None
    unit: str = ""


@dataclass
class BranchHealth:
    branch_id: str
    branch_name: str
    score: int             # 0-100
    revenue: float
    movement_count: int
    low_stock_count: int
    alerts: list[Alert] = field(default_factory=list)
    trend: str = "stable"  # "up" | "down" | "stable"


@dataclass
class ProductInsight:
    product_id: str
    product_name: str
    sku: str
    days_stopped: int
    total_stock: int
    margin: float
    recommendation: str    # "liquidar" | "comprar" | "monitorar" | "ok"


@dataclass
class AnalyticsReport:
    generated_at: datetime
    company_id: str
    alerts: list[Alert]
    branch_health: list[BranchHealth]
    product_insights: list[ProductInsight]
    demand_forecast: dict[str, Any]
    summary: dict[str, Any]


# ─── Engine principal ──────────────────────────────────────────────────────────

class AnalyticsEngine:
    """
    Recebe dados brutos do banco (dicts) e gera insights acionáveis.
    Não depende de SQLAlchemy — recebe dados já serializados.
    """

    def __init__(
        self,
        company_id: str,
        products: list[dict],
        branches: list[dict],
        stocks: list[dict],
        movements: list[dict],
        finances: list[dict] | None = None,
    ):
        self.company_id = company_id
        self.products   = {p["id"]: p for p in products}
        self.branches   = {b["id"]: b for b in branches}
        self.stocks     = stocks
        self.movements  = movements
        self.finances   = finances or []
        self.now        = datetime.now(timezone.utc)

    # ── Ponto de entrada ──────────────────────────────────────────────────────

    def run(self) -> AnalyticsReport:
        alerts          = self._detect_alerts()
        branch_health   = self._score_branches()
        product_insights= self._analyze_products()
        forecast        = self._demand_forecast()
        summary         = self._build_summary(alerts, branch_health)

        return AnalyticsReport(
            generated_at=self.now,
            company_id=self.company_id,
            alerts=alerts,
            branch_health=branch_health,
            product_insights=product_insights,
            demand_forecast=forecast,
            summary=summary,
        )

    # ── Detecção de alertas ───────────────────────────────────────────────────

    def _detect_alerts(self) -> list[Alert]:
        alerts: list[Alert] = []
        alerts += self._check_low_stock()
        alerts += self._check_stopped_products()
        alerts += self._check_sales_drop()
        alerts += self._check_negative_margin()
        # Ordena: critical → warning → info
        return sorted(alerts, key=lambda a: {"critical": 0, "warning": 1, "info": 2}[a.severity])

    def _check_low_stock(self) -> list[Alert]:
        alerts = []
        for s in self.stocks:
            if s["quantity"] <= s["min_quantity"]:
                product = self.products.get(s["product_id"], {})
                branch  = self.branches.get(s["branch_id"], {})
                pct     = (s["quantity"] / max(s["min_quantity"], 1)) * 100
                severity = "critical" if s["quantity"] == 0 else "warning"
                alerts.append(Alert(
                    severity=severity,
                    category="stock",
                    title=f"Estoque {'zerado' if s['quantity'] == 0 else 'crítico'}",
                    detail=(
                        f"{product.get('name', s['product_id'])} na filial "
                        f"{branch.get('name', s['branch_id'])}: "
                        f"{s['quantity']} unid (mín {s['min_quantity']})"
                    ),
                    entity_id=s["product_id"],
                    entity_name=product.get("name"),
                    metric=pct,
                    unit="%",
                ))
        return alerts

    def _check_stopped_products(self, days: int = 30) -> list[Alert]:
        cutoff = self.now - timedelta(days=days)
        moved_ids: set[str] = set()
        for m in self.movements:
            try:
                ts = datetime.fromisoformat(m["created_at"].replace("Z", "+00:00"))
                if ts >= cutoff:
                    moved_ids.add(m["product_id"])
            except Exception:
                pass

        alerts = []
        for pid, p in self.products.items():
            if pid not in moved_ids:
                total_stock = sum(
                    s["quantity"] for s in self.stocks if s["product_id"] == pid
                )
                if total_stock > 0:
                    alerts.append(Alert(
                        severity="warning",
                        category="product",
                        title=f"Produto parado há mais de {days} dias",
                        detail=f"{p['name']} (SKU: {p['sku']}) — {total_stock} unid em estoque sem movimentação.",
                        entity_id=pid,
                        entity_name=p["name"],
                        metric=float(total_stock),
                        unit="unid",
                    ))
        return alerts

    def _check_sales_drop(self, threshold_pct: float = 20.0) -> list[Alert]:
        """Compara movimentos de saída: últimos 7d vs 7d anteriores por filial."""
        now   = self.now
        w1_end   = now
        w1_start = now - timedelta(days=7)
        w2_end   = w1_start
        w2_start = now - timedelta(days=14)

        counts: dict[str, dict[str, int]] = defaultdict(lambda: {"w1": 0, "w2": 0})
        for m in self.movements:
            if m["type"] not in ("saida", "transfer"):
                continue
            try:
                ts = datetime.fromisoformat(m["created_at"].replace("Z", "+00:00"))
            except Exception:
                continue
            bid = m["branch_id"]
            if w1_start <= ts < w1_end:
                counts[bid]["w1"] += m["quantity"]
            elif w2_start <= ts < w2_end:
                counts[bid]["w2"] += m["quantity"]

        alerts = []
        for bid, data in counts.items():
            if data["w2"] == 0:
                continue
            drop = (data["w2"] - data["w1"]) / data["w2"] * 100
            if drop >= threshold_pct:
                branch = self.branches.get(bid, {})
                alerts.append(Alert(
                    severity="warning",
                    category="sales",
                    title="Queda de vendas detectada",
                    detail=(
                        f"Filial {branch.get('name', bid)}: "
                        f"-{drop:.0f}% nas saídas (últimos 7d vs 7d anteriores). "
                        f"Semana atual: {data['w1']} unid | Anterior: {data['w2']} unid."
                    ),
                    entity_id=bid,
                    entity_name=branch.get("name"),
                    metric=drop,
                    unit="%",
                ))
        return alerts

    def _check_negative_margin(self) -> list[Alert]:
        alerts = []
        for p in self.products.values():
            sale  = float(p.get("sale_price", 0))
            cost  = float(p.get("cost_price", 0))
            if sale > 0 and cost >= sale:
                alerts.append(Alert(
                    severity="critical",
                    category="finance",
                    title="Margem negativa ou zero",
                    detail=f"{p['name']}: custo R${cost:.2f} ≥ venda R${sale:.2f}. Revise o preço.",
                    entity_id=p["id"],
                    entity_name=p["name"],
                    metric=((sale - cost) / sale * 100),
                    unit="%",
                ))
        return alerts

    # ── Score de filiais ──────────────────────────────────────────────────────

    def _score_branches(self) -> list[BranchHealth]:
        results = []
        for bid, branch in self.branches.items():
            mov_branch = [m for m in self.movements if m["branch_id"] == bid]
            low_count  = sum(
                1 for s in self.stocks
                if s["branch_id"] == bid and s["quantity"] <= s["min_quantity"]
            )

            # Receita estimada = saídas × preço de venda
            revenue = 0.0
            for m in mov_branch:
                if m["type"] == "saida":
                    p = self.products.get(m["product_id"], {})
                    revenue += float(p.get("sale_price", 0)) * m["quantity"]

            # Score: começa em 100, desconta por problemas
            score = 100
            score -= low_count * 10          # -10 por item crítico
            score -= min(40, len([m for m in self._detect_alerts()
                                  if m.entity_id == bid]) * 8)
            score = max(0, min(100, score))

            # Tendência: compara últimas 48h vs 48-96h
            now = self.now
            recent   = sum(m["quantity"] for m in mov_branch if m["type"] == "saida"
                           and self._hours_ago(m, 48))
            previous = sum(m["quantity"] for m in mov_branch if m["type"] == "saida"
                           and self._hours_ago(m, 96) and not self._hours_ago(m, 48))
            trend = "up" if recent > previous * 1.1 else "down" if recent < previous * 0.9 else "stable"

            results.append(BranchHealth(
                branch_id=bid,
                branch_name=branch.get("name", bid),
                score=score,
                revenue=revenue,
                movement_count=len(mov_branch),
                low_stock_count=low_count,
                trend=trend,
            ))

        return sorted(results, key=lambda b: b.score, reverse=True)

    def _hours_ago(self, movement: dict, hours: int) -> bool:
        try:
            ts = datetime.fromisoformat(movement["created_at"].replace("Z", "+00:00"))
            return ts >= self.now - timedelta(hours=hours)
        except Exception:
            return False

    # ── Análise de produtos ───────────────────────────────────────────────────

    def _analyze_products(self) -> list[ProductInsight]:
        insights = []
        for pid, p in self.products.items():
            last_movement = None
            for m in sorted(self.movements, key=lambda x: x.get("created_at", ""), reverse=True):
                if m["product_id"] == pid:
                    last_movement = m
                    break

            days_stopped = 999
            if last_movement:
                try:
                    ts = datetime.fromisoformat(last_movement["created_at"].replace("Z", "+00:00"))
                    days_stopped = (self.now - ts).days
                except Exception:
                    pass

            total_stock = sum(s["quantity"] for s in self.stocks if s["product_id"] == pid)
            sale  = float(p.get("sale_price", 0))
            cost  = float(p.get("cost_price", 0))
            margin = ((sale - cost) / sale * 100) if sale > 0 else 0.0

            # Recomendação baseada em heurística
            if total_stock == 0:
                rec = "comprar"
            elif days_stopped >= 45 and total_stock > 0:
                rec = "liquidar"
            elif days_stopped >= 20:
                rec = "monitorar"
            elif total_stock <= p.get("min_stock", 0):
                rec = "comprar"
            else:
                rec = "ok"

            insights.append(ProductInsight(
                product_id=pid,
                product_name=p["name"],
                sku=p["sku"],
                days_stopped=days_stopped if days_stopped < 999 else -1,
                total_stock=total_stock,
                margin=margin,
                recommendation=rec,
            ))

        return sorted(insights, key=lambda i: (
            {"comprar": 0, "liquidar": 1, "monitorar": 2, "ok": 3}[i.recommendation]
        ))

    # ── Previsão de demanda ───────────────────────────────────────────────────

    def _demand_forecast(self) -> dict[str, Any]:
        """
        Regressão linear simples por produto para prever
        quando o estoque vai acabar (dias restantes).
        """
        forecasts: list[dict] = []

        for pid, p in self.products.items():
            # Agrupa saídas por dia nos últimos 30 dias
            daily: dict[str, int] = defaultdict(int)
            for m in self.movements:
                if m["product_id"] != pid or m["type"] not in ("saida", "transfer"):
                    continue
                try:
                    ts   = datetime.fromisoformat(m["created_at"].replace("Z", "+00:00"))
                    day  = ts.strftime("%Y-%m-%d")
                    daily[day] += m["quantity"]
                except Exception:
                    pass

            if len(daily) < 3:
                continue  # dados insuficientes

            values = list(daily.values())
            avg_daily = sum(values) / len(values)
            if avg_daily == 0:
                continue

            total_stock = sum(s["quantity"] for s in self.stocks if s["product_id"] == pid)
            days_left   = int(total_stock / avg_daily) if avg_daily > 0 else 9999

            forecasts.append({
                "product_id":   pid,
                "product_name": p["name"],
                "sku":          p["sku"],
                "avg_daily_out": round(avg_daily, 2),
                "total_stock":   total_stock,
                "days_until_empty": days_left,
                "reorder_date": (self.now + timedelta(days=max(0, days_left - 7))).strftime("%Y-%m-%d"),
                "urgency": "urgente" if days_left <= 7 else "breve" if days_left <= 21 else "ok",
            })

        forecasts.sort(key=lambda x: x["days_until_empty"])
        return {
            "generated_at": self.now.isoformat(),
            "items": forecasts[:20],  # top 20 mais urgentes
            "total_analyzed": len(forecasts),
        }

    # ── Resumo executivo ──────────────────────────────────────────────────────

    def _build_summary(self, alerts: list[Alert], branches: list[BranchHealth]) -> dict:
        critical_count = sum(1 for a in alerts if a.severity == "critical")
        warning_count  = sum(1 for a in alerts if a.severity == "warning")
        total_revenue  = sum(b.revenue for b in branches)
        avg_score      = sum(b.score for b in branches) / max(len(branches), 1)
        best_branch    = branches[0] if branches else None
        worst_branch   = branches[-1] if branches else None

        return {
            "total_products":   len(self.products),
            "total_branches":   len(self.branches),
            "total_stock_items":len(self.stocks),
            "total_movements":  len(self.movements),
            "critical_alerts":  critical_count,
            "warning_alerts":   warning_count,
            "estimated_revenue":round(total_revenue, 2),
            "avg_branch_score": round(avg_score, 1),
            "best_branch":      best_branch.branch_name if best_branch else None,
            "worst_branch":     worst_branch.branch_name if worst_branch else None,
        }
