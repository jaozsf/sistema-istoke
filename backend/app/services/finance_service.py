from decimal import Decimal
from sqlalchemy.ext.asyncio import AsyncSession
from app.repositories.finance_repository import FinanceRepository
from app.models.finance import Finance, FinanceType
from app.models.product import Product
from app.schemas.finance import FinanceSummaryOut
from app.core.timezone import br_day_range

# Sobretaxa de mão de obra por personalização (por unidade). Arte e borda são
# independentes — um copo pode sair com as duas (ordem de produção: arte
# primeiro, depois borda). Copo Ecológico não pode ter borda (derrete) —
# validado em StockService antes de chegar aqui.
ART_SURCHARGE    = {"revenue": Decimal("2.00"), "cost": Decimal("1.00")}
BORDER_SURCHARGE = {"revenue": Decimal("1.00"), "cost": Decimal("0.50")}


class FinanceService:
    def __init__(self, db: AsyncSession):
        self.db = db
        self.repo = FinanceRepository(db)

    async def record_sale(
        self, product: Product, quantity: int, branch_id: str,
        company_id: str, user_id: str | None, movement_id: str,
        has_art: bool = False, has_border: bool = False,
    ) -> None:
        """Lança receita + custo (COGS) referentes a uma saída de estoque (venda).
        Soma sobretaxa de mão de obra de arte e/ou borda quando aplicável —
        as duas podem estar presentes juntas no mesmo copo."""
        extra_revenue = Decimal(0)
        extra_cost = Decimal(0)
        labels = []
        if has_art:
            extra_revenue += ART_SURCHARGE["revenue"]
            extra_cost += ART_SURCHARGE["cost"]
            labels.append("personalizado")
        if has_border:
            extra_revenue += BORDER_SURCHARGE["revenue"]
            extra_cost += BORDER_SURCHARGE["cost"]
            labels.append("com borda")
        label = f" ({' + '.join(labels)})" if labels else ""

        receita = Finance(
            type=FinanceType.receita,
            amount=(product.sale_price + extra_revenue) * quantity,
            description=f"Venda: {product.name}{label} x{quantity}",
            reference_id=movement_id,
            company_id=company_id,
            branch_id=branch_id,
            user_id=user_id,
        )
        custo = Finance(
            type=FinanceType.custo,
            amount=(product.cost_price + extra_cost) * quantity,
            description=f"Custo (CMV{' + mão de obra' if label else ''}): {product.name}{label} x{quantity}",
            reference_id=movement_id,
            company_id=company_id,
            branch_id=branch_id,
            user_id=user_id,
        )
        self.db.add(receita)
        self.db.add(custo)
        await self.db.flush()

    async def get_summary(self, company_id: str, days: int = 1) -> FinanceSummaryOut:
        start, end = br_day_range(days)
        totals = await self.repo.sum_by_type(company_id, start, end)
        receita = totals.get("receita", 0.0)
        custo = totals.get("custo", 0.0)
        return FinanceSummaryOut(
            period_start=start, period_end=end,
            receita=receita, custo=custo, lucro=receita - custo,
        )

    async def list_recent(self, company_id: str, days: int = 30):
        start, end = br_day_range(days)
        return await self.repo.get_by_company_range(company_id, start, end)
