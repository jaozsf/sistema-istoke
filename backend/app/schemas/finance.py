from pydantic import BaseModel
from typing import Optional
from datetime import datetime
from decimal import Decimal


class FinanceOut(BaseModel):
    id: str
    type: str
    amount: Decimal
    description: Optional[str]
    reference_id: Optional[str]
    branch_id: Optional[str]
    created_at: datetime

    model_config = {"from_attributes": True}


class FinanceSummaryOut(BaseModel):
    period_start: datetime
    period_end: datetime
    receita: float
    custo: float
    lucro: float
