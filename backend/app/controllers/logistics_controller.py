from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession
from typing import List, Optional
from app.core.database import get_db
from app.core.security import get_current_user, require_admin, require_manager, require_roles
from app.services.logistics_service import (
    BoxStandardService, DistributorService, CustomerService, OrderService,
)
from app.schemas.logistics import (
    BoxStandardIn, BoxStandardOut,
    DistributorIn, DistributorOut,
    CustomerIn, CustomerOut,
    OrderCreate, OrderUpdate, OrderTransition, ItemCheck, OrderOut, OrderSummaryOut,
)

router = APIRouter(tags=["Logística & Pedidos"])

require_sales = require_roles("admin", "manager", "seller")


# ─── Padrões de caixa ─────────────────────────────────────────────────────────

@router.get("/box-standards", response_model=List[BoxStandardOut], summary="Padrões de caixa por produto")
async def list_box_standards(db: AsyncSession = Depends(get_db), current_user=Depends(get_current_user)):
    return await BoxStandardService(db).list(current_user.company_id)


@router.put("/box-standards/{product_id}", response_model=BoxStandardOut, summary="Define padrão de caixa (admin)")
async def upsert_box_standard(
    product_id: str, data: BoxStandardIn,
    db: AsyncSession = Depends(get_db), current_user=Depends(require_admin),
):
    return await BoxStandardService(db).upsert(product_id, data, current_user.company_id, current_user.id)


@router.delete("/box-standards/{product_id}", status_code=204)
async def delete_box_standard(
    product_id: str, db: AsyncSession = Depends(get_db), current_user=Depends(require_admin),
):
    await BoxStandardService(db).delete(product_id, current_user.company_id, current_user.id)


# ─── Distribuidoras ───────────────────────────────────────────────────────────

@router.get("/distributors", response_model=List[DistributorOut], summary="Distribuidoras")
async def list_distributors(
    include_inactive: bool = False,
    db: AsyncSession = Depends(get_db), current_user=Depends(get_current_user),
):
    return await DistributorService(db).list(current_user.company_id, include_inactive)


@router.post("/distributors", response_model=DistributorOut, status_code=201)
async def create_distributor(
    data: DistributorIn, db: AsyncSession = Depends(get_db), current_user=Depends(require_admin),
):
    return await DistributorService(db).create(data, current_user.company_id, current_user.id)


@router.put("/distributors/{distributor_id}", response_model=DistributorOut)
async def update_distributor(
    distributor_id: str, data: DistributorIn,
    db: AsyncSession = Depends(get_db), current_user=Depends(require_admin),
):
    return await DistributorService(db).update(distributor_id, data, current_user.company_id, current_user.id)


@router.delete("/distributors/{distributor_id}", status_code=204, summary="Desativa distribuidora")
async def deactivate_distributor(
    distributor_id: str, db: AsyncSession = Depends(get_db), current_user=Depends(require_admin),
):
    await DistributorService(db).deactivate(distributor_id, current_user.company_id, current_user.id)


# ─── Clientes ─────────────────────────────────────────────────────────────────

@router.get("/customers", response_model=List[CustomerOut], summary="Clientes")
async def list_customers(
    q: Optional[str] = None, mine: bool = False,
    db: AsyncSession = Depends(get_db), current_user=Depends(require_sales),
):
    seller_id = current_user.id if mine else None
    return await CustomerService(db).list(current_user.company_id, q, seller_id)


@router.post("/customers", response_model=CustomerOut, status_code=201)
async def create_customer(
    data: CustomerIn, db: AsyncSession = Depends(get_db), current_user=Depends(require_sales),
):
    return await CustomerService(db).create(data, current_user.company_id, current_user)


@router.put("/customers/{customer_id}", response_model=CustomerOut)
async def update_customer(
    customer_id: str, data: CustomerIn,
    db: AsyncSession = Depends(get_db), current_user=Depends(require_sales),
):
    return await CustomerService(db).update(customer_id, data, current_user)


@router.delete("/customers/{customer_id}", status_code=204)
async def deactivate_customer(
    customer_id: str, db: AsyncSession = Depends(get_db), current_user=Depends(require_manager),
):
    await CustomerService(db).deactivate(customer_id, current_user.company_id)


# ─── Pedidos ──────────────────────────────────────────────────────────────────

@router.get("/orders/summary", response_model=OrderSummaryOut, summary="Contagem por etapa")
async def orders_summary(db: AsyncSession = Depends(get_db), current_user=Depends(get_current_user)):
    return await OrderService(db).summary(current_user)


@router.get("/orders", response_model=List[OrderOut], summary="Pedidos")
async def list_orders(
    status: Optional[str] = Query(None, description="Etapa, lista separada por vírgula, ou 'abertos'"),
    limit: int = Query(100, ge=1, le=300),
    db: AsyncSession = Depends(get_db), current_user=Depends(get_current_user),
):
    return await OrderService(db).list(current_user, status, limit)


@router.post("/orders", response_model=OrderOut, status_code=201, summary="Vendedor envia pedido à fábrica")
async def create_order(
    data: OrderCreate, db: AsyncSession = Depends(get_db), current_user=Depends(require_sales),
):
    return await OrderService(db).create(data, current_user)


@router.get("/orders/{order_id}", response_model=OrderOut)
async def get_order(order_id: str, db: AsyncSession = Depends(get_db), current_user=Depends(get_current_user)):
    return await OrderService(db).get_out(order_id, current_user)


@router.patch("/orders/{order_id}", response_model=OrderOut, summary="Troca distribuidora/observação")
async def update_order(
    order_id: str, data: OrderUpdate,
    db: AsyncSession = Depends(get_db), current_user=Depends(require_sales),
):
    return await OrderService(db).update(order_id, data, current_user)


@router.post("/orders/{order_id}/transition", response_model=OrderOut, summary="Avança etapa do pedido")
async def transition_order(
    order_id: str, data: OrderTransition,
    db: AsyncSession = Depends(get_db), current_user=Depends(get_current_user),
):
    return await OrderService(db).transition(order_id, data, current_user)


@router.put("/orders/{order_id}/items/{item_id}/check", response_model=OrderOut, summary="Conferência de caixas")
async def check_item(
    order_id: str, item_id: str, data: ItemCheck,
    db: AsyncSession = Depends(get_db), current_user=Depends(get_current_user),
):
    return await OrderService(db).check_item(order_id, item_id, data.checked_boxes, current_user)
