"""
Testes unitários do motor de analytics e previsão de demanda.
Rode com: pytest tests/test_analytics.py -v
Não precisa de banco — usa dados mockados.
"""
import pytest
from datetime import datetime, timedelta, timezone
from app.ai.analytics import AnalyticsEngine, Alert
from app.ai.predictions import DemandForecaster, run_forecasts

# ── Fixtures ──────────────────────────────────────────────────────────────────

NOW = datetime.now(timezone.utc)


def _ts(days_ago: int = 0, hours_ago: int = 0) -> str:
    return (NOW - timedelta(days=days_ago, hours=hours_ago)).isoformat()


COMPANY_ID = "comp-001"

PRODUCTS = [
    {"id": "prod-001", "sku": "A-001", "name": "Notebook Dell", "sale_price": 8900.0, "cost_price": 5200.0, "min_stock": 5, "category": "Computadores"},
    {"id": "prod-002", "sku": "B-012", "name": "Mouse Logitech", "sale_price": 620.0,  "cost_price": 310.0,  "min_stock": 10, "category": "Periféricos"},
    {"id": "prod-003", "sku": "C-001", "name": "Margem Negativa","sale_price": 100.0,  "cost_price": 150.0,  "min_stock": 5,  "category": "Teste"},
]

BRANCHES = [
    {"id": "br-001", "name": "Matriz SP",  "city": "São Paulo",  "state": "SP"},
    {"id": "br-002", "name": "Filial RJ",  "city": "Rio de Janeiro", "state": "RJ"},
]

STOCKS = [
    {"id": "st-001", "product_id": "prod-001", "branch_id": "br-001", "quantity": 2,   "min_quantity": 5},   # crítico
    {"id": "st-002", "product_id": "prod-002", "branch_id": "br-001", "quantity": 50,  "min_quantity": 10},  # ok
    {"id": "st-003", "product_id": "prod-001", "branch_id": "br-002", "quantity": 0,   "min_quantity": 5},   # zerado
    {"id": "st-004", "product_id": "prod-003", "branch_id": "br-001", "quantity": 20,  "min_quantity": 5},   # ok mas margem negativa
]

MOVEMENTS_RICH = [
    # Produto 001: saídas regulares (últimos 30 dias)
    *[{"id": f"m{i}", "type": "saida",   "quantity": 2, "product_id": "prod-001", "branch_id": "br-001", "created_at": _ts(days_ago=i)} for i in range(1, 20)],
    # Produto 002: algumas saídas recentes
    *[{"id": f"m{20+i}", "type": "saida","quantity": 5, "product_id": "prod-002", "branch_id": "br-001", "created_at": _ts(days_ago=i)} for i in range(1, 8)],
    # Entrada (não deve contar como demanda)
    {"id": "m99", "type": "entrada", "quantity": 10, "product_id": "prod-001", "branch_id": "br-001", "created_at": _ts(days_ago=1)},
]

MOVEMENTS_SPARSE = [
    {"id": "ms1", "type": "saida", "quantity": 1, "product_id": "prod-001", "branch_id": "br-001", "created_at": _ts(days_ago=50)},
]


# ── Testes de AnalyticsEngine ─────────────────────────────────────────────────

class TestAnalyticsEngine:

    def _engine(self, movements=None):
        return AnalyticsEngine(
            company_id=COMPANY_ID,
            products=PRODUCTS,
            branches=BRANCHES,
            stocks=STOCKS,
            movements=movements or MOVEMENTS_RICH,
        )

    def test_run_returns_report(self):
        report = self._engine().run()
        assert report.company_id == COMPANY_ID
        assert report.generated_at is not None
        assert isinstance(report.alerts, list)
        assert isinstance(report.branch_health, list)
        assert isinstance(report.product_insights, list)

    def test_detects_critical_stock(self):
        report = self._engine().run()
        critical = [a for a in report.alerts if a.category == "stock" and a.severity == "critical"]
        # prod-001 no br-002 está zerado → critical
        assert len(critical) >= 1
        assert any("zerado" in a.title.lower() for a in critical)

    def test_detects_warning_stock(self):
        report = self._engine().run()
        warning = [a for a in report.alerts if a.category == "stock" and a.severity == "warning"]
        # prod-001 no br-001 está com 2 (mín 5) → warning
        assert len(warning) >= 1

    def test_detects_negative_margin(self):
        report = self._engine().run()
        finance_alerts = [a for a in report.alerts if a.category == "finance"]
        assert len(finance_alerts) >= 1
        assert any("Margem Negativa" in a.entity_name for a in finance_alerts)

    def test_detects_stopped_products(self):
        # Produto 003 não tem movimentos → deve aparecer como parado
        report = self._engine(movements=MOVEMENTS_SPARSE).run()
        stopped = [a for a in report.alerts if a.category == "product"]
        assert len(stopped) >= 1

    def test_branch_health_sorted_by_score(self):
        report = self._engine().run()
        scores = [b.score for b in report.branch_health]
        assert scores == sorted(scores, reverse=True)

    def test_branch_health_score_in_range(self):
        report = self._engine().run()
        for b in report.branch_health:
            assert 0 <= b.score <= 100

    def test_summary_fields(self):
        report = self._engine().run()
        s = report.summary
        assert s["total_products"] == len(PRODUCTS)
        assert s["total_branches"] == len(BRANCHES)
        assert "critical_alerts" in s
        assert "estimated_revenue" in s

    def test_product_insights_recommendations(self):
        report = self._engine().run()
        recs = {p.recommendation for p in report.product_insights}
        assert recs.issubset({"comprar", "liquidar", "monitorar", "ok"})

    def test_alerts_sorted_by_severity(self):
        report = self._engine().run()
        order  = {"critical": 0, "warning": 1, "info": 2}
        for i in range(len(report.alerts) - 1):
            assert order[report.alerts[i].severity] <= order[report.alerts[i+1].severity]

    def test_no_crash_empty_data(self):
        engine = AnalyticsEngine(COMPANY_ID, [], [], [], [])
        report = engine.run()
        assert report.summary["total_products"] == 0
        assert report.alerts == []


# ── Testes de DemandForecaster ────────────────────────────────────────────────

class TestDemandForecaster:

    def test_forecast_returns_predictions(self):
        forecaster = DemandForecaster(PRODUCTS, STOCKS, MOVEMENTS_RICH)
        preds = forecaster.forecast_all()
        assert len(preds) > 0

    def test_prediction_fields(self):
        forecaster = DemandForecaster(PRODUCTS, STOCKS, MOVEMENTS_RICH)
        preds = forecaster.forecast_all()
        for p in preds:
            assert p.product_id
            assert p.avg_daily_demand >= 0
            assert p.days_until_empty >= 0
            assert 0.0 <= p.confidence <= 1.0
            assert p.reorder_urgency in ("imediato", "semana", "mes", "ok")

    def test_sorted_by_urgency(self):
        forecaster = DemandForecaster(PRODUCTS, STOCKS, MOVEMENTS_RICH)
        preds = forecaster.forecast_all()
        # Mais urgentes (menos dias) primeiro
        for i in range(len(preds) - 1):
            assert preds[i].days_until_empty <= preds[i+1].days_until_empty

    def test_no_crash_sparse_data(self):
        forecaster = DemandForecaster(PRODUCTS, STOCKS, MOVEMENTS_SPARSE)
        preds = forecaster.forecast_all()
        # Pode ser lista vazia se dados insuficientes — mas não deve lançar exceção
        assert isinstance(preds, list)

    def test_run_forecasts_dict(self):
        result = run_forecasts(PRODUCTS, STOCKS, MOVEMENTS_RICH)
        assert "predictions" in result
        assert "total_forecasted" in result
        assert "urgent_reorders" in result
        assert isinstance(result["predictions"], list)

    def test_seasonal_patterns(self):
        forecaster = DemandForecaster(PRODUCTS, STOCKS, MOVEMENTS_RICH)
        patterns = forecaster.seasonal_patterns()
        for pat in patterns:
            assert len(pat.weekday_indices) == 7
            assert pat.product_id


# ── Testes de alertas específicos ─────────────────────────────────────────────

class TestAlertPriorities:

    def test_critical_before_warning(self):
        engine = AnalyticsEngine(COMPANY_ID, PRODUCTS, BRANCHES, STOCKS, MOVEMENTS_RICH)
        report = engine.run()
        first_non_critical = next(
            (i for i, a in enumerate(report.alerts) if a.severity != "critical"), None
        )
        if first_non_critical is not None:
            for a in report.alerts[:first_non_critical]:
                assert a.severity == "critical"

    def test_zero_stock_is_critical(self):
        engine = AnalyticsEngine(COMPANY_ID, PRODUCTS, BRANCHES, STOCKS, MOVEMENTS_RICH)
        report = engine.run()
        zero_alerts = [a for a in report.alerts if "zerado" in a.title.lower()]
        assert all(a.severity == "critical" for a in zero_alerts)

    def test_negative_margin_is_critical(self):
        engine = AnalyticsEngine(COMPANY_ID, PRODUCTS, BRANCHES, STOCKS, MOVEMENTS_RICH)
        report = engine.run()
        margin_alerts = [a for a in report.alerts if a.category == "finance"]
        assert all(a.severity == "critical" for a in margin_alerts)
